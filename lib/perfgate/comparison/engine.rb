# frozen_string_literal: true

require_relative "workload_comparison"
require_relative "diagnostics"
require_relative "../fingerprints/compatibility"
require "time"
require "shellwords"

module Perfgate
  module Comparison
    # Builds the schema_version 2 comparison-result document (spec
    # section 14.2) from a baseline run-result and a candidate
    # run-result. This is the seam between the fingerprinting/statistics
    # primitives and the CLI: it never touches storage or exit codes
    # (that's Policy::Engine's job), only produces the structured
    # decision document.
    #
    # Compatibility is checked first (spec section 15): when the runs are
    # incompatible, no per-workload metric decisions are computed at all
    # -- Perfgate never silently compares runs it can't vouch for.
    module Engine
      SCHEMA_VERSION = 2

      module_function

      def compare(baseline_run:, candidate_run:, config: Perfgate.configuration)
        compatibility = evaluate_compatibility(baseline_run, candidate_run, config)
        workloads = workloads_for(compatibility, baseline_run, candidate_run, config)

        build_document(baseline_run, candidate_run, compatibility, workloads, config)
      end

      def build_document(baseline_run, candidate_run, compatibility, workloads, config)
        {
          "schema_version" => SCHEMA_VERSION,
          "created_at" => Time.now.utc.iso8601,
          "baseline_run_id" => baseline_run["run_id"],
          "candidate_run_id" => candidate_run["run_id"],
          "reference_design" => candidate_run.dig("experiment_plan", "reference_design"),
          "compatibility" => compatibility,
          "decision" => overall_decision(compatibility, workloads),
          "workloads" => workloads,
          "diagnostics" => diagnostics(baseline_run, candidate_run, compatibility),
          "analysis_configuration" => config.to_h.fetch(:comparison),
          "policy" => { "version" => 1, "configuration" => config.policy },
          "reproduction_command" => reproduction_command(baseline_run, candidate_run, config)
        }
      end

      def workloads_for(compatibility, baseline_run, candidate_run, config)
        return [] if compatibility["status"] == "incompatible"

        WorkloadComparison.compare_all(baseline_run, candidate_run, config)
      end

      def evaluate_compatibility(baseline_run, candidate_run, config)
        result = Fingerprints::Compatibility.evaluate(
          baseline_components: baseline_run.fetch("fingerprint", {}),
          candidate_components: candidate_run.fetch("fingerprint", {}), config: config
        )
        add_schema_difference(result, baseline_run, candidate_run)
        add_reference_design_difference(result, baseline_run, candidate_run)
        add_baseline_age_difference(result, baseline_run, candidate_run, config)
        result["status"] = Fingerprints::Compatibility.status_for(result["differences"])
        result
      end

      def add_schema_difference(result, baseline_run, candidate_run)
        baseline = baseline_run["schema_version"]
        candidate = candidate_run["schema_version"]
        return if baseline == candidate && !baseline.nil?

        result["differences"] << {
          "field" => "schema_version", "severity" => "strict",
          "reason" => baseline.nil? || candidate.nil? ? "missing" : "changed",
          "baseline" => baseline, "candidate" => candidate
        }
      end

      def add_reference_design_difference(result, baseline_run, candidate_run)
        baseline = baseline_run.dig("experiment_plan", "reference_design")
        candidate = candidate_run.dig("experiment_plan", "reference_design")
        return if baseline == candidate && !baseline.nil?

        result["differences"] << {
          "field" => "reference_design", "severity" => "strict",
          "reason" => baseline.nil? || candidate.nil? ? "missing" : "changed",
          "baseline" => baseline, "candidate" => candidate
        }
      end

      def add_baseline_age_difference(result, baseline_run, candidate_run, config)
        maximum = config.comparison_max_baseline_age_seconds
        return unless maximum

        baseline_time = Time.parse(baseline_run.fetch("created_at"))
        candidate_time = Time.parse(candidate_run.fetch("created_at"))
        age = candidate_time - baseline_time
        return if age >= 0 && age <= maximum

        result["differences"] << {
          "field" => "baseline_age_seconds", "severity" => "strict", "reason" => "stale",
          "baseline" => age, "candidate" => maximum
        }
      rescue KeyError, ArgumentError, TypeError
        result["differences"] << {
          "field" => "baseline_age_seconds", "severity" => "strict", "reason" => "missing",
          "baseline" => baseline_run["created_at"], "candidate" => candidate_run["created_at"]
        }
      end

      def overall_decision(compatibility, workloads)
        return "incompatible" if compatibility["status"] == "incompatible"
        return "inconclusive" if workloads.empty?

        decisions = workloads.map { |w| w["decision"] }
        return "fail" if decisions.include?("fail")
        return "inconclusive" if decisions.include?("inconclusive")
        return "incomparable" if decisions.include?("incomparable")
        return "warn" if decisions.intersect?(%w[warn removed_workload new_workload])
        return "warn" if compatibility["status"] == "compatible_with_warnings"

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

      def reproduction_command(baseline_run, candidate_run, config)
        baseline = File.join(config.storage_path, "runs", baseline_run["run_id"].to_s)
        candidate = File.join(config.storage_path, "runs", candidate_run["run_id"].to_s)
        "bundle exec perfgate compare --baseline #{Shellwords.escape(baseline)} " \
          "--candidate #{Shellwords.escape(candidate)} --config perfgate.yml"
      end
    end
  end
end
