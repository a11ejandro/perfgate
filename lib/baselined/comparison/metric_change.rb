# frozen_string_literal: true

require_relative "../statistics/summary"

module Baselined
  module Comparison
    # Shared helpers for building a metric comparison result and for
    # computing the baseline->candidate change that every decision path
    # (statistical or deterministic) needs (spec section 14.2's
    # `workloads[].metrics` entries).
    module MetricChange
      module_function

      def inconclusive(metric)
        base_fields(metric).merge("decision" => "inconclusive")
      end

      def base_fields(metric)
        {
          "metric" => metric.to_s,
          "baseline_median" => nil,
          "candidate_median" => nil,
          "change_percent" => nil,
          "absolute_change" => nil,
          "confidence" => nil,
          "practically_significant" => false,
          "noisy" => false
        }
      end

      def summarize(metric, baseline_samples, candidate_samples)
        baseline_summary = Statistics::Summary.call(baseline_samples)
        candidate_summary = Statistics::Summary.call(candidate_samples)
        absolute_change = candidate_summary["median"] - baseline_summary["median"]
        change_percent = percent_change(baseline_summary["median"], absolute_change)

        build_change(metric, baseline_summary, candidate_summary, absolute_change, change_percent)
      end

      def build_change(metric, baseline_summary, candidate_summary, absolute_change, change_percent)
        {
          metric: metric.to_s,
          baseline_summary: baseline_summary,
          candidate_summary: candidate_summary,
          absolute_change: absolute_change,
          change_percent: change_percent
        }
      end

      def percent_change(baseline_median, absolute_change)
        return 0.0 if baseline_median.zero?

        ((absolute_change / baseline_median.to_f) * 100).round(2)
      end

      def result(change, confidence:, practically_significant:, noisy:, decision:)
        change_fields(change).merge(
          "confidence" => confidence, "practically_significant" => practically_significant,
          "noisy" => noisy, "decision" => decision
        )
      end

      def change_fields(change)
        {
          "metric" => change[:metric],
          "baseline_median" => change[:baseline_summary]["median"],
          "candidate_median" => change[:candidate_summary]["median"],
          "change_percent" => change[:change_percent],
          "absolute_change" => change[:absolute_change]
        }
      end

      # A metric is "noisy" when its own baseline spread (MAD relative to
      # its median) is large enough that a modest shift in medians could
      # plausibly be explained by run-to-run variance alone (spec 16.5).
      def noisy?(baseline_summary, config)
        median = baseline_summary["median"]
        return false if median.zero?

        (baseline_summary["mad"] / median.to_f) > config.comparison_noise_ratio_threshold
      end
    end
  end
end
