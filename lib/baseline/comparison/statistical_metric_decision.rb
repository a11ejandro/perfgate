# frozen_string_literal: true

require_relative "metric_change"
require_relative "../statistics/mann_whitney_u"

module Baseline
  module Comparison
    # Statistical decision path used for continuous, noisy metrics
    # (duration, sql_duration, allocations): combines a practical
    # threshold check with a one-sided Mann-Whitney U test, and
    # downgrades a would-be fail to a warn when the metric is noisy
    # (spec sections 16.3-16.5).
    module StatisticalMetricDecision
      module_function

      def call(metric, baseline_samples, candidate_samples, config)
        change = MetricChange.summarize(metric, baseline_samples, candidate_samples)
        thresholds = threshold_for(metric, config)
        p_value = Statistics::MannWhitneyU.one_sided_p(baseline_samples, candidate_samples)

        significance = significance_flags(change, thresholds, p_value, config)
        noisy = MetricChange.noisy?(change[:baseline_summary], config)
        decision = decide(significance[:exceeds_failure], significance[:statistically_significant],
                          significance[:practically_significant], noisy)

        MetricChange.result(change, confidence: (1 - p_value).round(4),
                                    practically_significant: significance[:practically_significant], noisy: noisy,
                                    decision: decision)
      end

      def significance_flags(change, thresholds, p_value, config)
        alpha = 1 - config.comparison_confidence_level
        clears_floor = change[:absolute_change].abs >= thresholds[:minimum_absolute]
        {
          practically_significant: breaches?(change, thresholds[:warning_percent], thresholds[:minimum_absolute]),
          exceeds_failure: breaches?(change, thresholds[:failure_percent], thresholds[:minimum_absolute]),
          statistically_significant: clears_floor && change[:absolute_change].positive? && p_value < alpha
        }
      end

      def decide(exceeds_failure, statistically_significant, practically_significant, noisy)
        if exceeds_failure && statistically_significant
          noisy ? "warn" : "fail"
        elsif practically_significant || statistically_significant
          "warn"
        else
          "pass"
        end
      end

      def threshold_for(metric, config)
        raw = config.dig(:comparison, :practical_thresholds, metric.to_sym) || {}
        {
          warning_percent: raw[:warning_percent] || Float::INFINITY,
          failure_percent: raw[:failure_percent] || Float::INFINITY,
          # minimum_absolute_ms is configured in milliseconds, but samples
          # (and therefore change[:absolute_change]) are always in the
          # metric's raw unit, nanoseconds for duration/sql_duration - so
          # it must be converted before comparison.
          minimum_absolute: minimum_absolute_ns(raw)
        }
      end

      def minimum_absolute_ns(raw)
        return raw[:minimum_absolute_ms] * 1_000_000 if raw[:minimum_absolute_ms]

        raw[:minimum_absolute] || 0
      end

      def breaches?(change, percent_threshold, minimum_absolute)
        change[:change_percent].abs >= percent_threshold && change[:absolute_change].abs >= minimum_absolute
      end
    end
  end
end
