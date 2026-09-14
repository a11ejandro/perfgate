# frozen_string_literal: true

require_relative "metric_decision"
require_relative "diagnostics"

module Perfgate
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
        family_size = statistical_family_size(baseline_by_id, candidate_by_id)

        (baseline_by_id.keys | candidate_by_id.keys).map do |id|
          compare_one(id, baseline_by_id[id], candidate_by_id[id], config, family_size)
        end
      end

      def index_by_id(run)
        run.fetch("workloads", []).to_h { |workload| [workload["id"], workload] }
      end

      def compare_one(id, baseline_workload, candidate_workload, config, family_size = 1)
        return missing_workload_result(id, "new_workload") unless baseline_workload
        return missing_workload_result(id, "removed_workload") unless candidate_workload
        return execution_error_result(id, baseline_workload, candidate_workload) unless
          completed?(baseline_workload) && completed?(candidate_workload)
        return incomplete_assurance_result(id, baseline_workload, candidate_workload) unless
          evidence_contract_complete?(baseline_workload) && evidence_contract_complete?(candidate_workload)

        definition_changed = baseline_workload["definition_hash"] != candidate_workload["definition_hash"]
        return incomparable_workload_result(id) if definition_changed

        metrics = metric_decisions(baseline_workload, candidate_workload, config, family_size)
        { "id" => id, "decision" => workload_decision(metrics),
          "assurance" => candidate_workload["assurance"], "metrics" => metrics,
          "diagnostics" => Diagnostics.for_workload(metrics) }
      end

      def completed?(workload)
        workload["status"] == "completed"
      end

      def execution_error_result(id, baseline_workload, candidate_workload)
        messages = []
        messages << "Baseline execution error: #{baseline_workload["error"]}" unless completed?(baseline_workload)
        messages << "Candidate execution error: #{candidate_workload["error"]}" unless completed?(candidate_workload)
        {
          "id" => id,
          "decision" => "inconclusive",
          "execution_error" => true,
          "execution_status" => {
            "baseline" => baseline_workload["status"],
            "candidate" => candidate_workload["status"]
          },
          "metrics" => {},
          "diagnostics" => messages
        }
      end

      def assurance_complete?(workload)
        assurance = workload["assurance"]
        return false unless assurance.is_a?(Hash)

        claim = assurance["claim"]
        owner = assurance["owner"]
        dataset = assurance["dataset"]
        directions = assurance["metric_directions"]
        effects = assurance["minimum_effects"]
        claim.is_a?(String) && !claim.strip.empty? && owner.is_a?(String) && !owner.strip.empty? &&
          dataset.is_a?(Hash) && dataset.values.compact.any? && directions.is_a?(Hash) && directions.any? &&
          effects.is_a?(Hash) && effects.any?
      end

      def evidence_contract_complete?(workload)
        definition_hash = workload["definition_hash"]
        source_digest = workload.dig("source", "digest")
        assurance_complete?(workload) && definition_hash.is_a?(String) && !definition_hash.empty? &&
          source_digest.is_a?(String) && !source_digest.empty?
      end

      def incomplete_assurance_result(id, baseline_workload, candidate_workload)
        missing = []
        missing << "baseline" unless evidence_contract_complete?(baseline_workload)
        missing << "candidate" unless evidence_contract_complete?(candidate_workload)
        {
          "id" => id,
          "decision" => "incomparable",
          "assurance" => candidate_workload["assurance"] || {},
          "metrics" => {},
          "diagnostics" => ["Incomplete assurance claim, workload definition, or source provenance for " \
                            "#{missing.join(" and ")} workload."]
        }
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

      def metric_decisions(baseline_workload, candidate_workload, config, family_size)
        sample_keys(baseline_workload, candidate_workload).each_with_object({}) do |sample_key, acc|
          metric = SAMPLE_KEY_TO_METRIC[sample_key]
          next unless metric

          baseline_samples = samples_for(baseline_workload, sample_key)
          candidate_samples = samples_for(candidate_workload, sample_key)
          acc[metric] = if baseline_samples.empty? || candidate_samples.empty?
                          MetricChange.inconclusive(
                            metric, baseline_samples: baseline_samples, candidate_samples: candidate_samples,
                                    reason: "metric observations missing from one or both runs"
                          )
                        else
                          MetricDecision.call(metric: metric, baseline_samples: baseline_samples,
                                              candidate_samples: candidate_samples, config: config,
                                              family_size: family_size)
                        end
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
        return "inconclusive" if decisions.empty?
        return "fail" if decisions.include?("fail")
        return "inconclusive" if decisions.include?("inconclusive")
        return "warn" if decisions.include?("warn")

        "pass"
      end

      def statistical_family_size(baseline_by_id, candidate_by_id)
        count = (baseline_by_id.keys & candidate_by_id.keys).sum do |id|
          baseline_workload = baseline_by_id[id]
          candidate_workload = candidate_by_id[id]
          next 0 unless completed?(baseline_workload) && completed?(candidate_workload)
          next 0 unless evidence_contract_complete?(baseline_workload) && evidence_contract_complete?(candidate_workload)
          next 0 unless baseline_workload["definition_hash"] == candidate_workload["definition_hash"]

          sample_keys(baseline_workload, candidate_workload).count do |sample_key|
            metric = SAMPLE_KEY_TO_METRIC[sample_key]
            metric && !MetricDecision::DETERMINISTIC_METRICS.include?(metric) &&
              !samples_for(baseline_workload, sample_key).empty? && !samples_for(candidate_workload, sample_key).empty?
          end
        end
        [count, 1].max
      end
    end
  end
end
