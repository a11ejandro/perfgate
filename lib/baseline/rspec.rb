# frozen_string_literal: true

require "rspec/core"
require_relative "rspec/id_resolver"
require_relative "rspec/workload_builder"
require_relative "rspec/discovery"

module Baseline
  # RSpec integration entry point. Require "baseline/rspec" (typically
  # from spec_helper.rb) to enable `:baseline`-tagged examples and
  # `Baseline.measure`. See spec section 9 for the public API contract.
  module RSpec
  end
end
