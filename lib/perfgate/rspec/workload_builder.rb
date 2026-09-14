# frozen_string_literal: true

require_relative "../workloads/workload"
require_relative "id_resolver"
require "digest"

module Perfgate
  module RSpec
    # Builds a Workloads::Workload that wraps a single RSpec example.
    #
    # Each call re-instantiates the example group and re-runs the example
    # via RSpec's own `Example#run(instance, reporter)`, which is safe to
    # invoke repeatedly: it resets the example's execution result and
    # exercises the full before/around/after hook chain each time (spec
    # section 12.2, "reset workload state" + "execute measured samples").
    # A ::RSpec::Core::NullReporter discards RSpec's own reporting, since
    # Perfgate does its own result collection.
    class WorkloadBuilder
      def initialize(defaults:, dataset: {}, practical_thresholds: {})
        @defaults = defaults
        @dataset = dataset
        @practical_thresholds = practical_thresholds
      end

      def build(example)
        options = example.metadata[:perfgate]
        options = {} unless options.is_a?(Hash)

        metrics = options.fetch(:metrics, @defaults.fetch(:metrics))
        Workloads::Workload.new(
          id: IdResolver.resolve(example),
          samples: options.fetch(:samples, @defaults.fetch(:samples)),
          warmup: options.fetch(:warmup, @defaults.fetch(:warmup)),
          metrics: metrics,
          assurance: assurance_for(options, metrics),
          source: source_for(example)
        ) { run_example(example) }
      end

      private

      def assurance_for(options, metrics)
        {
          "claim" => options[:claim],
          "owner" => options[:owner],
          "dataset" => options.fetch(:dataset, @dataset),
          "metric_directions" => options.fetch(
            :metric_directions, metrics.to_h { |metric| [metric.to_s, "lower_is_better"] }
          ),
          "minimum_effects" => options.fetch(:minimum_effects, @practical_thresholds)
        }
      end

      def source_for(example)
        path = example.metadata[:file_path]
        expanded = File.expand_path(path.to_s)
        {
          "location" => [path, example.metadata[:line_number]].compact.join(":"),
          "digest" => File.file?(expanded) ? "sha256:#{Digest::SHA256.file(expanded).hexdigest}" : nil
        }
      end

      def run_example(example)
        instance = example.example_group.new
        example.run(instance, ::RSpec::Core::NullReporter)

        exception = example.execution_result.exception
        return unless exception

        raise Perfgate::WorkloadError,
              "workload #{example.full_description.inspect} failed: #{exception.message}"
      end
    end
  end
end
