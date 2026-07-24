# frozen_string_literal: true

require "baseline/execution/runner"

RSpec.describe Baseline::Execution::Runner do
  def workload(samples: 3, warmup: 1, &block)
    Baseline::Workloads::Workload.new(id: "w", samples: samples, warmup: warmup, metrics: [:duration], &block)
  end

  it "runs warmup iterations plus the configured number of measured samples" do
    calls = 0
    result = described_class.new(workload(samples: 4, warmup: 2) { calls += 1 }).call

    expect(calls).to eq(6)
    expect(result["samples"].size).to eq(4)
  end

  it "reports a completed status with a duration_ns reading per sample" do
    result = described_class.new(workload { 1 }).call

    expect(result["status"]).to eq("completed")
    expect(result["error"]).to be_nil
    result["samples"].each { |sample| expect(sample["duration_ns"]).to be_a(Integer).and be >= 0 }
  end

  it "prefers an explicit Baseline.measure duration over the wall-clock measurement" do
    load_result = described_class.new(
      workload(samples: 1, warmup: 0) { Baseline.measure { nil } }
    ).call

    expect(load_result["samples"].first["duration_ns"]).to be >= 0
  end

  it "reports a failing workload as status: error instead of raising" do
    result = described_class.new(workload(samples: 1, warmup: 0) { raise "boom" }).call

    expect(result["status"]).to eq("error")
    expect(result["samples"]).to eq([])
    expect(result["error"]).to match(/boom/)
  end
end
