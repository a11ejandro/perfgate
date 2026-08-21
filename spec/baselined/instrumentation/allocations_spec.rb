# frozen_string_literal: true

require "baselined/instrumentation/allocations"

RSpec.describe Baselined::Instrumentation::Allocations do
  it "reports a positive allocation delta for a block that allocates objects" do
    started = described_class.start
    Array.new(1000) { Object.new }
    result = described_class.finish(started)

    expect(result["allocations"]).to be >= 1000
  end
end
