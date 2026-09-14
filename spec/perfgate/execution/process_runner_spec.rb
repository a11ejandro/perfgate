# frozen_string_literal: true

require "perfgate/execution/process_runner"
require "perfgate/workloads/workload"

RSpec.describe Perfgate::Execution::ProcessRunner do
  def workload(&block)
    Perfgate::Workloads::Workload.new(id: "isolated", samples: 2, warmup: 0, metrics: [:duration], &block)
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


  it "reloads RSpec-backed workloads in a clean process instead of forking loaded native state" do
    source = File.expand_path("../../fixtures/subprocess_workload.rb", __dir__)
    reloadable = Perfgate::Workloads::Workload.new(
      id: "fixture.clean_subprocess", samples: 3, warmup: 0, metrics: [:duration],
      source: { "location" => "#{source}:6", "digest" => "sha256:fixture" }
    ) { raise "the inherited workload must not execute" }

    result = described_class.new(reloadable).call

    expect(result["status"]).to eq("completed")
    expect(result["samples"].size).to eq(8)
  end
end
