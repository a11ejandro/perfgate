# frozen_string_literal: true

require_relative "../workloads/workload"
require_relative "id_resolver"

module Baseline
  module RSpec
    # Builds a Workloads::Workload that wraps a single RSpec example.
    #
    # Each call re-instantiates the example group and re-runs the example
    # via RSpec's own `Example#run(instance, reporter)`, which is safe to
    # invoke repeatedly: it resets the example's execution result and
    # exercises the full before/around/after hook chain each time (spec
    # section 12.2, "reset workload state" + "execute measured samples").
    # A ::RSpec::Core::NullReporter discards RSpec's own reporting, since
    # Baseline does its own result collection.
    class WorkloadBuilder
      def initialize(defaults:)
        @defaults = defaults
      end

      def build(example)
        options = example.metadata[:baseline]
        options = {} unless options.is_a?(Hash)

        Workloads::Workload.new(
          id: IdResolver.resolve(example),
          samples: options.fetch(:samples, @defaults.fetch(:samples)),
          warmup: options.fetch(:warmup, @defaults.fetch(:warmup)),
          metrics: options.fetch(:metrics, @defaults.fetch(:metrics))
        ) { run_example(example) }
      end

      private

      def run_example(example)
        instance = example.example_group.new
        example.run(instance, ::RSpec::Core::NullReporter)

        exception = example.execution_result.exception
        return unless exception

        raise Baseline::WorkloadError,
              "workload #{example.full_description.inspect} failed: #{exception.message}"
      end
    end
  end
end
