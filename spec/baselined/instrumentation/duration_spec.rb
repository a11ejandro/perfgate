# frozen_string_literal: true

require "baselined/instrumentation/duration"

RSpec.describe Baselined::Instrumentation::Duration do
  it "measures elapsed wall-clock time between start and finish" do
    started = described_class.start
    sleep 0.01
    result = described_class.finish(started)

    expect(result["duration_ns"]).to be >= 10_000_000
  end
end
