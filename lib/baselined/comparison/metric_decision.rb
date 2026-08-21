# frozen_string_literal: true

require_relative "metric_change"
require_relative "statistical_metric_decision"
require_relative "deterministic_metric_decision"

module Baselined
  module Comparison
    # Decides pass/warn/fail/inconclusive for a single metric on a single
    # workload (spec section 16). A regression is only ever reported as
    # "fail" when it clears both bars: a practically-significant change
    # (spec 16.4's thresholds) and statistical support that it isn't just
    # sampling noise (spec 16.3's Mann-Whitney test) -- see
    # spikes/FINDINGS.md for why Milestone 0 settled on requiring both.
    # `sql_count` is the one exception: it's compared deterministically
    # (spec 16.3), since query counts are rarely continuous/noisy the way
    # timing and allocation metrics are.
    module MetricDecision
      DETERMINISTIC_METRICS = %w[sql_count].freeze

      module_function

      def call(metric:, baseline_samples:, candidate_samples:, config: Baselined.configuration)
        return MetricChange.inconclusive(metric) unless enough_samples?(baseline_samples, candidate_samples, config)

        if DETERMINISTIC_METRICS.include?(metric.to_s)
          DeterministicMetricDecision.call(metric, baseline_samples, candidate_samples, config)
        else
          StatisticalMetricDecision.call(metric, baseline_samples, candidate_samples, config)
        end
      end

      def enough_samples?(baseline_samples, candidate_samples, config)
        minimum = config.comparison_minimum_samples
        baseline_samples.size >= minimum && candidate_samples.size >= minimum
      end
    end
  end
end
