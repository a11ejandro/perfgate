# frozen_string_literal: true

require "baseline/instrumentation/gc"

RSpec.describe Baseline::Instrumentation::Gc do
  it "reports zero deltas when no collection happens" do
    started = described_class.start
    result = described_class.finish(started)

    expect(result).to eq("gc_count" => 0, "gc_minor_count" => 0, "gc_major_count" => 0)
  end

  it "reports a positive gc_count delta when a collection is forced" do
    started = described_class.start
    GC.start
    result = described_class.finish(started)

    expect(result["gc_count"]).to be >= 1
  end
end
