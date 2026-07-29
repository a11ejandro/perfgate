# frozen_string_literal: true

module Baseline
  module Statistics
    # Basic summary statistics for a set of raw sample values, used to
    # populate the `summary` block of a run result (spec sections 14.1
    # and 16.2).
    module Summary
      module_function

      def call(values)
        return empty if values.empty?

        sorted = values.sort
        med = median(sorted)

        central_tendency(values, sorted, med).merge("count" => values.size)
      end

      def central_tendency(values, sorted, med)
        {
          "mean" => mean(values).round,
          "median" => med.round,
          "min" => sorted.first.round,
          "max" => sorted.last.round,
          "mad" => mad(sorted, med).round,
          "p90" => percentile(sorted, 90).round
        }
      end

      def mean(values)
        values.sum / values.size.to_f
      end

      def median(sorted)
        percentile(sorted, 50)
      end

      # Median absolute deviation: a robust spread measure, less sensitive
      # to outliers than standard deviation.
      def mad(sorted, med)
        deviations = sorted.map { |v| (v - med).abs }.sort
        percentile(deviations, 50)
      end

      def percentile(sorted, pct)
        return sorted.first.to_f if sorted.size == 1

        rank = (pct / 100.0) * (sorted.size - 1)
        lower = sorted[rank.floor]
        upper = sorted[rank.ceil]
        lower + ((upper - lower) * (rank - rank.floor))
      end

      def empty
        { "mean" => 0, "median" => 0, "min" => 0, "max" => 0, "mad" => 0, "p90" => 0, "count" => 0 }
      end
    end
  end
end
