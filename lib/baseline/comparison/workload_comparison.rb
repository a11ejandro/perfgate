# frozen_string_literal: true

require_relative "metric_decision"
require_relative "diagnostics"

module Baseline
  module Comparison
    # Matches baseline/candidate workloads by id and produces each
    # workload's decision entry in the comparison-result document (spec
    # 14.2), including the deterministic per-workload diagnostics (spec
    # 20.3). Split out of Engine to keep both modules under RuboCop's
    # module-length limit.
    module WorkloadComparison
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

      def compare_all(baseline_run, candidate_run, config)
        baseline_by_id = index_by_id(baseline_run)
        candidate_by_id = index_by_id(candidate_run)

        (baseline_by_id.keys | candidate_by_id.keys).map do |id|
          compare_one(id, baseline_by_id[id], candidate_by_id[id], config)
        end
      end

      def index_by_id(run)
        run.fetch("workloads", []).to_h { |workload| [workload["id"], workload] }
      end

      def compare_one(id, baseline_workload, candidate_workload, config)
        return missing_workload_result(id, "new_workload") unless baseline_workload
        return missing_workload_result(id, "removed_workload") unless candidate_workload

        definition_changed = baseline_workload["definition_hash"] != candidate_workload["definition_hash"]
        return incomparable_workload_result(id) if definition_changed

        metrics = metric_decisions(baseline_workload, candidate_workload, config)
        { "id" => id, "decision" => workload_decision(metrics), "metrics" => metrics,
          "diagnostics" => Diagnostics.for_workload(metrics) }
      end

      def missing_workload_result(id, reason)
        message = if reason == "new_workload"
                    "new workload with no prior baseline run"
                  else
                    "workload removed since the baseline run"
                  end
        { "id" => id, "decision" => reason, "metrics" => {}, "diagnostics" => [message] }
      end

      def incomparable_workload_result(id)
        { "id" => id, "decision" => "incomparable", "metrics" => {},
          "diagnostics" => ["Workload definition changed since the baseline run; comparison skipped."] }
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
    end
  end
end
