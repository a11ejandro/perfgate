# frozen_string_literal: true

module Baseline
  module Execution
    # Thread-local scratch space that `Baseline.measure` writes into when
    # called from inside a running workload sample, per the explicit
    # measurement contract in spec section 9.1.
    class SampleContext
      def self.current
        Thread.current[:baseline_sample_context]
      end

      def self.current=(context)
        Thread.current[:baseline_sample_context] = context
      end

      # Runs the block with a fresh context active, restoring whatever
      # was active beforehand (nil, normally) once the block finishes.
      def self.with_new
        previous = current
        context = new
        self.current = context
        yield context
      ensure
        self.current = previous
      end

      attr_reader :explicit_duration_seconds

      def record_duration_seconds(seconds)
        @explicit_duration_seconds = seconds
      end
    end
  end
end
