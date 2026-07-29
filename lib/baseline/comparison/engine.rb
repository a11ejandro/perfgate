# frozen_string_literal: true

require_relative "metric_decision"
require_relative "../fingerprints/compatibility"

module Baseline
  module Comparison
    # Builds the schema_version 1 comparison-result document (spec
    # section 14.2) from a baseline run-result and a candidate
    # run-result. This is the seam between the fingerprinting/statistics
    # primitives and the CLI: it never touches storage or exit codes
    # (that's Policy::Engine's job), only produces the structured
    # decision document.
    #
    # Compatibility is checked first (spec section 15): when the runs are
    # incompatible, no per-workload metric decisions are computed at all
    # -- Baseline never silently compares runs it can't vouch for.
    module Engine
      SCHEMA_VERSION = 1

      # Maps the raw sample keys instrumentation writes (spec section 13)
      # to the metric names practical_thresholds/fingerprint config uses
      # (spec section 16.4). gc_* keys are deliberately left unmapped:
      # GC activity is diagnostic-only and never drives a decision.
      SAMPLE_KEY_TO_METRIC = {
        "duration_ns" => "duration",
        "sql_count" => "sql_count",
        "sql_duration_ns" => "sql_duration",
        "allocations" => "allocations"
      }.freeze

      module_function

      def compare(baseline_run:, candidate_run:, config: Baseline.configuration)
        compatibility = evaluate_compatibility(baseline_run, candidate_run, config)
        workloads = workloads_for(compatibility, baseline_run, candidate_run, config)

        build_document(baseline_run, candidate_run, compatibility, workloads)
      end

      def build_document(baseline_run, candidate_run, compatibility, workloads)
        {
          "schema_version" => SCHEMA_VERSION,
          "baseline_run_id" => baseline_run["run_id"],
          "candidate_run_id" => candidate_run["run_id"],
          "compatibility" => compatibility,
          "decision" => overall_decision(compatibility, workloads),
          "workloads" => workloads,
          "diagnostics" => diagnostics(baseline_run, candidate_run)
        }
      end

      def workloads_for(compatibility, baseline_run, candidate_run, config)
        return [] if compatibility["status"] == "incompatible"

        compare_workloads(baseline_run, candidate_run, config)
      end

      def evaluate_compatibility(baseline_run, candidate_run, config)
        Fingerprints::Compatibility.evaluate(
          baseline_components: baseline_run.fetch("fingerprint", {}),
          candidate_components: candidate_run.fetch("fingerprint", {}), config: config
        )
      end

      def compare_workloads(baseline_run, candidate_run, config)
        baseline_by_id = index_by_id(baseline_run)
        candidate_by_id = index_by_id(candidate_run)

        (baseline_by_id.keys | candidate_by_id.keys).map do |id|
          compare_workload(id, baseline_by_id[id], candidate_by_id[id], config)
        end
      end

      def index_by_id(run)
        run.fetch("workloads", []).to_h { |workload| [workload["id"], workload] }
      end

      def compare_workload(id, baseline_workload, candidate_workload, config)
        return missing_workload_result(id, "new_workload") unless baseline_workload
        return missing_workload_result(id, "removed_workload") unless candidate_workload

        definition_changed = baseline_workload["definition_hash"] != candidate_workload["definition_hash"]
        return incomparable_workload_result(id) if definition_changed

        metrics = metric_decisions(baseline_workload, candidate_workload, config)
        { "id" => id, "decision" => workload_decision(metrics), "metrics" => metrics }
      end

      def missing_workload_result(id, reason)
        { "id" => id, "decision" => reason, "metrics" => {} }
      end

      def incomparable_workload_result(id)
        { "id" => id, "decision" => "incomparable", "metrics" => {} }
      end

      def metric_decisions(baseline_workload, candidate_workload, config)
        sample_keys(baseline_workload, candidate_workload).each_with_object({}) do |sample_key, acc|
          metric = SAMPLE_KEY_TO_METRIC[sample_key]
          next unless metric

          baseline_samples = samples_for(baseline_workload, sample_key)
          candidate_samples = samples_for(candidate_workload, sample_key)
          next if baseline_samples.empty? || candidate_samples.empty?

          acc[metric] = MetricDecision.call(metric: metric, baseline_samples: baseline_samples,
                                            candidate_samples: candidate_samples, config: config)
        end
      end

      def sample_keys(baseline_workload, candidate_workload)
        (baseline_workload.fetch("summary", {}).keys + candidate_workload.fetch("summary", {}).keys).uniq
      end

      def samples_for(workload, sample_key)
        workload.fetch("samples", []).filter_map { |sample| sample[sample_key] }
      end

      def workload_decision(metrics)
        decisions = metrics.values.map { |m| m["decision"] }
        return "fail" if decisions.include?("fail")
        return "warn" if decisions.include?("warn")
        return "inconclusive" if decisions.include?("inconclusive") && decisions.all? { |d| d != "pass" }

        "pass"
      end

      def overall_decision(compatibility, workloads)
        return "incompatible" if compatibility["status"] == "incompatible"

        decisions = workloads.map { |w| w["decision"] }
        return "fail" if decisions.include?("fail")
        return "warn" if decisions.intersect?(%w[warn incomparable removed_workload new_workload])

        "pass"
      end

      def diagnostics(baseline_run, candidate_run)
        diagnostics = []
        diagnostics << { "code" => "empty_baseline", "message" => "baseline run has no workloads" } if
          baseline_run.fetch("workloads", []).empty?
        diagnostics << { "code" => "empty_candidate", "message" => "candidate run has no workloads" } if
          candidate_run.fetch("workloads", []).empty?
        diagnostics
      end
    end
  end
end
