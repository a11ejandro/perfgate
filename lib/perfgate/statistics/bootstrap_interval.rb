# frozen_string_literal: true

require "digest"
require "json"
require_relative "summary"

module Perfgate
  module Statistics
    # Deterministic non-parametric bootstrap intervals for the independent
    # stored-baseline design. The resampling unit is one workload observation.
    module BootstrapInterval
      ITERATIONS = 4_000

      module_function

      def median_change(baseline, candidate, confidence_level:, identity: nil)
        return nil if baseline.empty? || candidate.empty?

        rng = Random.new(seed_for(baseline, candidate, identity))
        absolute = []
        percent = []

        ITERATIONS.times do
          baseline_median = resampled_median(baseline, rng)
          candidate_median = resampled_median(candidate, rng)
          difference = candidate_median - baseline_median

          absolute << difference
          percent << ((difference / baseline_median.to_f) * 100) unless baseline_median.zero?
        end

        {
          "method" => "independent_nonparametric_bootstrap_median_difference",
          "confidence_level" => confidence_level,
          "iterations" => ITERATIONS,
          "absolute" => bounds(absolute, confidence_level),
          "percent" => percent.size == ITERATIONS ? bounds(percent, confidence_level) : nil
        }
      end

      def resampled_median(values, rng)
        sample = Array.new(values.size) { values[rng.rand(values.size)] }.sort
        Summary.median(sample)
      end

      def bounds(values, confidence_level)
        sorted = values.sort
        tail = (1.0 - confidence_level) / 2.0
        {
          "lower" => Summary.percentile(sorted, tail * 100),
          "upper" => Summary.percentile(sorted, (1.0 - tail) * 100)
        }
      end

      def seed_for(baseline, candidate, identity)
        payload = JSON.generate([identity, baseline, candidate])
        Digest::SHA256.hexdigest(payload)[0, 16].to_i(16)
      end
    end
  end
end
