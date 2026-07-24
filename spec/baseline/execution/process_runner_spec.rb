# frozen_string_literal: true

require "baseline/execution/process_runner"

RSpec.describe Baseline::Execution::ProcessRunner do
  def workload(&block)
    Baseline::Workloads::Workload.new(id: "isolated", samples: 2, warmup: 0, metrics: [:duration], &block)
  end

  it "executes the workload in a child process and relays a completed result as JSON" do
    result = described_class.new(workload { 1 + 1 }).call

    expect(result["id"]).to eq("isolated")
    expect(result["status"]).to eq("completed")
    expect(result["samples"].size).to eq(2)
  end

  it "does not affect the parent process's state" do
    marker = "unset"
    described_class.new(workload { marker = "set from child" }).call

    expect(marker).to eq("unset")
  end

  it "relays a workload error raised inside the child back to the parent" do
    result = described_class.new(workload { raise "child boom" }).call

    expect(result["status"]).to eq("error")
    expect(result["error"]).to match(/child boom/)
  end

  it "synthesizes an error result if the child exits without writing a payload" do
    result = described_class.new(workload { exit!(1) }).call

    expect(result["status"]).to eq("error")
    expect(result["error"]).to match(/exited without a result/)
  end
end
