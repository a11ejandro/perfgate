# frozen_string_literal: true

require_relative "metric_change"
require_relative "statistical_metric_decision"
require_relative "deterministic_metric_decision"

module Perfgate
  module Comparison
    # Decides pass/warn/fail/inconclusive for a single metric on a single
    # workload (spec section 16). Continuous metrics use an
    # interval-based directional-MEI rule; too-small samples remain
    # explicitly inconclusive rather than being interpreted as a pass.
    # `sql_count` uses a deterministic comparison only after within-run
    # stability has been established.
    module MetricDecision
      DETERMINISTIC_METRICS = %w[sql_count].freeze

      module_function

      def call(metric:, baseline_samples:, candidate_samples:, config: Perfgate.configuration, family_size: 1)
        unless enough_samples?(baseline_samples, candidate_samples, config)
          return MetricChange.inconclusive(metric, baseline_samples: baseline_samples,
                                                    candidate_samples: candidate_samples)
        end

        if DETERMINISTIC_METRICS.include?(metric.to_s)
          DeterministicMetricDecision.call(metric, baseline_samples, candidate_samples, config)
        else
          StatisticalMetricDecision.call(metric, baseline_samples, candidate_samples, config, family_size: family_size)
        end
      end

      def enough_samples?(baseline_samples, candidate_samples, config)
        minimum = config.comparison_minimum_samples
        baseline_samples.size >= minimum && candidate_samples.size >= minimum
      end
    end
  end
end
