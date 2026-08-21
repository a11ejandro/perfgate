# frozen_string_literal: true

require "baselined/execution/runner"
require "baselined/workloads/workload"

RSpec.describe Baselined::Execution::Runner do
  def workload(samples: 3, warmup: 1, metrics: [:duration], &block)
    Baselined::Workloads::Workload.new(id: "w", samples: samples, warmup: warmup, metrics: metrics, &block)
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

  it "attaches the workload's definition_hash regardless of outcome" do
    completed = described_class.new(workload { 1 }).call
    errored = described_class.new(workload { raise "boom" }).call

    expect(completed["definition_hash"]).to start_with("sha256:")
    expect(errored["definition_hash"]).to eq(completed["definition_hash"])
  end

  it "prefers an explicit Baselined.measure duration over the wall-clock measurement" do
    load_result = described_class.new(
      workload(samples: 1, warmup: 0) { Baselined.measure { nil } }
    ).call

    expect(load_result["samples"].first["duration_ns"]).to be >= 0
  end

  it "only collects allocation counts for code inside the Baselined.measure block" do
    result = described_class.new(
      workload(samples: 1, warmup: 0, metrics: %i[duration allocations]) do
        Array.new(500) { Object.new } # outside the measured block: must not be counted
        Baselined.measure { Array.new(3) { Object.new } }
      end
    ).call

    expect(result["samples"].first["allocations"]).to be_between(3, 20)
  end

  it "reports no non-duration metrics when Baselined.measure is never called" do
    result = described_class.new(
      workload(samples: 1, warmup: 0, metrics: %i[duration allocations sql_count]) { Array.new(500) { Object.new } }
    ).call

    expect(result["samples"].first.keys).to eq(["duration_ns"])
  end

  it "reports a failing workload as status: error instead of raising" do
    result = described_class.new(workload(samples: 1, warmup: 0) { raise "boom" }).call

    expect(result["status"]).to eq("error")
    expect(result["samples"]).to eq([])
    expect(result["error"]).to match(/boom/)
  end
end
