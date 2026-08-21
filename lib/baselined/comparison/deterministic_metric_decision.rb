# frozen_string_literal: true

require_relative "metric_change"

module Baselined
  module Comparison
    # Deterministic decision path used for count-like metrics (currently
    # only sql_count): no statistical test is applied, since query
    # counts don't carry the same run-to-run noise that timing and
    # allocation metrics do (spec section 16.3).
    module DeterministicMetricDecision
      module_function

      def call(metric, baseline_samples, candidate_samples, config)
        change = MetricChange.summarize(metric, baseline_samples, candidate_samples)
        thresholds = config.dig(:comparison, :practical_thresholds, metric.to_sym) || {}
        decision = verdict(change, thresholds)

        MetricChange.result(change, confidence: nil, practically_significant: decision != "pass", noisy: false,
                                    decision: decision)
      end

      def verdict(change, thresholds)
        warning_absolute = thresholds[:warning_absolute] || 0
        failure_percent = thresholds[:failure_percent] || Float::INFINITY

        return "pass" if change[:absolute_change] <= 0
        return "pass" if change[:absolute_change] < warning_absolute

        change[:change_percent] >= failure_percent ? "fail" : "warn"
      end
    end
  end
end
