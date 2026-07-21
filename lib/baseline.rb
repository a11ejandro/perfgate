# frozen_string_literal: true

require_relative "baseline/version"
require_relative "baseline/errors"

# Baseline is a CI-native performance assurance tool for Ruby on Rails
# applications. It converts selected RSpec examples into repeatable
# performance workloads and compares them against a compatible
# default-branch baseline to produce a merge-gate decision.
module Baseline
  class << self
    # Explicitly marks the block whose execution should be measured by
    # Baseline. See section 9.1 of the technical specification for the
    # RSpec integration contract. Implemented as part of the RSpec
    # integration milestone.
    def measure
      raise NotImplementedError, "Baseline.measure is not implemented yet"
    end
  end
end
