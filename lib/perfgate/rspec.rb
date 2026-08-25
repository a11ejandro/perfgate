# frozen_string_literal: true

require "rspec/core"
require_relative "rspec/id_resolver"
require_relative "rspec/workload_builder"
require_relative "rspec/discovery"

module Perfgate
  # RSpec integration entry point. Require "baselined/rspec" (typically
  # from spec_helper.rb) to enable `:baseline`-tagged examples and
  # `Perfgate.measure`. See spec section 9 for the public API contract.
  module RSpec
  end
end
