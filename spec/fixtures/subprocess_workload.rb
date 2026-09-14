# frozen_string_literal: true

require_relative "../spec_helper"
require "perfgate/rspec"

RSpec.describe "clean subprocess fixture",
               perfgate: {
                 id: "fixture.clean_subprocess",
                 claim: "The clean child executes the selected workload",
                 owner: "perfgate-tests",
                 dataset: { id: "fixture" },
                 metrics: [:duration]
               } do
  it "runs" do
    Perfgate.measure { 1 + 1 }
  end
end
