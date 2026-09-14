# frozen_string_literal: true

require_relative "metric_change"
require_relative "../statistics/mann_whitney_u"
require_relative "../statistics/bootstrap_interval"

module Perfgate
  module Comparison
    # Statistical decision path used for continuous, noisy metrics
    # (duration, sql_duration, allocations): combines directional
    # materiality thresholds with an independent-sample bootstrap
    # interval for median change. Mann-Whitney U is recorded only as a
    # distributional diagnostic; its p-value does not drive the verdict.
    module StatisticalMetricDecision
      module_function

      def call(metric, baseline_samples, candidate_samples, config, family_size: 1)
        change = MetricChange.summarize(metric, baseline_samples, candidate_samples)
        thresholds = threshold_for(metric, config)
        p_value = Statistics::MannWhitneyU.one_sided_p(baseline_samples, candidate_samples)
        confidence_level = family_adjusted_confidence(config.comparison_confidence_level, family_size)
        interval = Statistics::BootstrapInterval.median_change(
          baseline_samples, candidate_samples, confidence_level: confidence_level, identity: metric.to_s
        )
        noisy = MetricChange.noisy?(change[:baseline_summary], config)
        practical = breaches_values?(change[:absolute_change], change[:change_percent],
                                     thresholds[:warning_percent], thresholds[:minimum_absolute])
        decision = decide(change, interval, thresholds, practical)
        rule = rule_for(decision, confidence_level, thresholds, family_size)

        MetricChange.result(change, interval: interval, p_value: p_value.round(6), thresholds: thresholds,
                                    rule: rule, practically_significant: practical, noisy: noisy,
                                    decision: decision)
      end

      def decide(change, interval, thresholds, practical)
        return "inconclusive" unless interval && interval["percent"]

        lower_absolute = interval.dig("absolute", "lower")
        lower_percent = interval.dig("percent", "lower")
        upper_absolute = interval.dig("absolute", "upper")
        upper_percent = interval.dig("percent", "upper")

        return "fail" if breaches_values?(lower_absolute, lower_percent,
                                           thresholds[:failure_percent], thresholds[:minimum_absolute])
        return "pass" unless breaches_values?(upper_absolute, upper_percent,
                                               thresholds[:warning_percent], thresholds[:minimum_absolute])

        practical && change[:absolute_change].positive? ? "warn" : "inconclusive"
      end

      def family_adjusted_confidence(confidence_level, family_size)
        return confidence_level if family_size <= 1

        1.0 - ((1.0 - confidence_level) / family_size)
      end

      def rule_for(decision, confidence_level, thresholds, family_size)
        adjustment = family_size > 1 ? "Bonferroni family size #{family_size}; " : ""
        "#{adjustment}#{(confidence_level * 100).round(3)}% bootstrap interval; " \
          "PASS upper bound below warning MEI, FAIL lower bound above failure MEI; result=#{decision}; " \
          "warning=#{thresholds[:warning_percent]}%, failure=#{thresholds[:failure_percent]}%, " \
          "absolute floor=#{thresholds[:minimum_absolute]}"
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

      def breaches_values?(absolute_change, percent_change, percent_threshold, minimum_absolute)
        return false unless absolute_change&.positive? && percent_change&.positive?
        return false unless percent_threshold.finite?

        percent_change >= percent_threshold && absolute_change >= minimum_absolute
      end
    end
  end
end
