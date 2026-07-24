# frozen_string_literal: true

module Baseline
  module Workloads
    # A deterministic executable path measured by Baseline (spec section
    # 7). Normally backed by one RSpec example, but the callable is kept
    # generic so the execution engine can be exercised without RSpec.
    class Workload
      attr_reader :id, :samples, :warmup, :metrics

      def initialize(id:, samples:, warmup:, metrics: [:duration], &block)
        raise ArgumentError, "workload #{id.inspect} requires a block to execute" unless block

        @id = id
        @samples = samples
        @warmup = warmup
        @metrics = metrics
        @block = block
      end

      def call
        @block.call
      end
    end
  end
end
