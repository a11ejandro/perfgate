# frozen_string_literal: true

require_relative "../instrumentation"

module Perfgate
  module Execution
    # Thread-local scratch space that `Perfgate.measure` writes into when
    # called from inside a running workload sample, per the explicit
    # measurement contract in spec section 9.1 / 13.1: metrics other than
    # the wall-clock duration fallback are only ever collected during the
    # explicit `Perfgate.measure` block, never for the workload as a
    # whole (Milestone 2 exit criterion: "metrics are correctly isolated
    # to the measurement block").
    class SampleContext
      def self.current
        Thread.current[:baseline_sample_context]
      end

      def self.current=(context)
        Thread.current[:baseline_sample_context] = context
      end

      # Runs the block with a fresh context active for the given metric
      # names, restoring whatever was active beforehand (nil, normally)
      # once the block finishes.
      def self.with_new(metrics: [:duration])
        previous = current
        context = new(metrics: metrics)
        self.current = context
        yield context
      ensure
        self.current = previous
      end

      def initialize(metrics: [:duration])
        @collectors = Instrumentation.collectors_for(metrics)
        @data = {}
        @measured = false
      end

      # Runs the block with every configured collector started
      # beforehand and stopped immediately after, merging their results
      # into this sample's data. Safe to call more than once per sample;
      # repeated calls accumulate (numeric values are summed).
      def measure
        @measured = true
        started = @collectors.map { |collector| [collector, collector.start] }
        result = yield
        started.each { |collector, state| accumulate(collector.finish(state)) }
        result
      end

      def measured?
        @measured
      end

      attr_reader :data

      private

      def accumulate(collected)
        collected.each { |key, value| @data[key] = @data.fetch(key, 0) + value }
      end
    end
  end
end
