# frozen_string_literal: true

module Perfgate
  module Policy
    # Turns a comparison-result document (or the absence of one) into
    # the PASS/WARN/FAIL/INCOMPARABLE decision and CI exit code baseline
    # exits with (spec section 17):
    #
    #   0 PASS, WARN, or INCONCLUSIVE under a non-blocking policy
    #   1 Performance FAIL
    #   2 Configuration error       (raised directly by the CLI, not here)
    #   3 Execution error           (raised directly by the CLI, not here)
    #   4 Missing baseline under a strict policy
    #   5 Incompatible baseline under a strict policy
    #
    # `config.policy` separates evidence from enforcement. Advisory mode
    # preserves FAIL evidence without blocking CI. It also controls how "soft" signals (an incompatible
    # fingerprint, a new/removed workload) escalate into a hard FAIL --
    # every one of those keys defaults to "warn" (never blocking) and
    # only escalates when explicitly set to "fail".
    module Engine
      EXIT_CODES = {
        "pass" => 0, "warn" => 0, "inconclusive" => 0, "fail" => 1,
        "execution_error" => 3, "missing_baseline" => 4, "incomparable" => 5
      }.freeze
      ESCALATING_WORKLOAD_DECISIONS = { "new_workload" => :new_workload, "removed_workload" => :removed_workload,
                                        "incomparable" => :incompatible }.freeze

      module_function

      def evaluate(comparison_result:, config: Perfgate.configuration)
        status = status_for(comparison_result, config)
        {
          "status" => status,
          "evidence_status" => comparison_result["decision"],
          "exit_code" => EXIT_CODES.fetch(status),
          "rule" => policy_rule(status, config)
        }
      end

      # A separate entry point for the CLI: there is no comparison result
      # at all when no prior baseline run could be found to compare
      # against (spec section 17's exit code 4).
      def evaluate_missing_baseline(config: Perfgate.configuration)
        status = config.policy[:missing_baseline] == "fail" ? "missing_baseline" : "warn"
        { "status" => status, "evidence_status" => "incomparable", "exit_code" => EXIT_CODES.fetch(status),
          "rule" => "policy.missing_baseline=#{config.policy[:missing_baseline]}" }
      end

      def status_for(comparison_result, config)
        return incompatible_status(config) if %w[incompatible incomparable].include?(comparison_result["decision"])
        return "execution_error" if execution_error?(comparison_result)

        escalation = workload_escalation(comparison_result, config)
        return escalation if escalation

        metric_status(comparison_result, config)
      end

      def incompatible_status(config)
        config.policy[:incompatible] == "fail" ? "incomparable" : "warn"
      end

      def workload_escalation(comparison_result, config)
        workloads = comparison_result.fetch("workloads", [])
        ESCALATING_WORKLOAD_DECISIONS.each do |decision, policy_key|
          next unless config.policy[policy_key] == "fail"
          next unless workloads.any? { |w| w["decision"] == decision }

          return "fail"
        end
        nil
      end

      def metric_status(comparison_result, config)
        return "warn" if config.policy[:mode] == "advisory" && comparison_result["decision"] == "fail"

        case comparison_result["decision"]
        when "fail" then "fail"
        when "warn" then config.policy[:fail_on] == "warn" ? "fail" : "warn"
        when "inconclusive" then config.policy[:inconclusive] == "fail" ? "fail" : "inconclusive"
        else "pass"
        end
      end

      def execution_error?(comparison_result)
        comparison_result.fetch("workloads", []).any? { |workload| workload["execution_error"] }
      end

      def policy_rule(status, config)
        "policy version 1; mode=#{config.policy[:mode]}; fail_on=#{config.policy[:fail_on]}; " \
          "inconclusive=#{config.policy[:inconclusive]}; " \
          "incompatible=#{config.policy[:incompatible]}; result=#{status}"
      end
    end
  end
end
