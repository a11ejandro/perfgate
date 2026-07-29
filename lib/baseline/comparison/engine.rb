# frozen_string_literal: true

require_relative "workload_comparison"
require_relative "diagnostics"
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
          "diagnostics" => diagnostics(baseline_run, candidate_run, compatibility)
        }
      end

      def workloads_for(compatibility, baseline_run, candidate_run, config)
        return [] if compatibility["status"] == "incompatible"

        WorkloadComparison.compare_all(baseline_run, candidate_run, config)
      end

      def evaluate_compatibility(baseline_run, candidate_run, config)
        Fingerprints::Compatibility.evaluate(
          baseline_components: baseline_run.fetch("fingerprint", {}),
          candidate_components: candidate_run.fetch("fingerprint", {}), config: config
        )
      end

      def overall_decision(compatibility, workloads)
        return "incompatible" if compatibility["status"] == "incompatible"

        decisions = workloads.map { |w| w["decision"] }
        return "fail" if decisions.include?("fail")
        return "warn" if decisions.intersect?(%w[warn incomparable removed_workload new_workload])

        "pass"
      end

      def diagnostics(baseline_run, candidate_run, compatibility)
        diagnostics = []
        diagnostics << { "code" => "empty_baseline", "message" => "baseline run has no workloads" } if
          baseline_run.fetch("workloads", []).empty?
        diagnostics << { "code" => "empty_candidate", "message" => "candidate run has no workloads" } if
          candidate_run.fetch("workloads", []).empty?
        Diagnostics.environment_changed_rules(compatibility).each do |message|
          diagnostics << { "code" => "environment_changed", "message" => message }
        end
        diagnostics
      end
    end
  end
end
