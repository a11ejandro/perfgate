# frozen_string_literal: true

require_relative "workload_builder"

module Baselined
  module RSpec
    # Discovers RSpec examples tagged for Baseline (`:baseline` metadata,
    # spec section 9.1) after spec files have been loaded, and registers
    # a Workload for each one.
    #
    # `::RSpec.world.all_examples` is a private RSpec::Core API, but it is
    # widely relied on by tooling that inspects a loaded suite and has
    # been stable across RSpec 3.x releases.
    module Discovery
      module_function

      def call(registry: Baselined.registry, builder: default_builder)
        ::RSpec.world.all_examples.each do |example|
          next unless example.metadata[:baselined]

          registry.register(builder.build(example))
        end
        registry
      end

      def default_builder
        WorkloadBuilder.new(defaults: Baselined.configuration.execution_defaults)
      end
    end
  end
end
