# frozen_string_literal: true

require_relative "baseline/version"
require_relative "baseline/errors"
require_relative "baseline/config"
require_relative "baseline/workloads/registry"
require_relative "baseline/execution/sample_context"

# Baseline is a CI-native performance assurance tool for Ruby on Rails
# applications. It converts selected RSpec examples into repeatable
# performance workloads and compares them against a compatible
# default-branch baseline to produce a merge-gate decision.
module Baseline
  class << self
    # Explicitly marks the block whose execution should be measured by
    # Baseline (spec section 9.1). Outside of a running workload sample
    # (e.g. called directly in a plain unit test) this simply executes
    # the block and returns its value without recording anything.
    def measure(&block)
      context = Execution::SampleContext.current
      return block.call unless context

      context.measure(&block)
    end

    # The active configuration, loaded via Config.load or Config.default.
    # `baseline run` assigns this after loading baseline.yml.
    def configuration
      @configuration ||= Config.default
    end

    attr_writer :configuration

    # The process-wide workload registry that RSpec discovery populates.
    def registry
      Workloads::Registry.instance
    end
  end
end
