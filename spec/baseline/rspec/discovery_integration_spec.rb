# frozen_string_literal: true

require "rspec/core/sandbox"
require "baseline/rspec"

# Exercises the exit criterion for Milestone 1 (spec section 28): "one
# workload can be run repeatedly and serialized". Uses RSpec::Core::Sandbox
# so a nested, `:baseline`-tagged example group can be defined and run
# without disturbing the real RSpec::Core::World running this very spec.
RSpec.describe "Baseline RSpec integration" do
  around do |example|
    RSpec::Core::Sandbox.sandboxed { example.run }
  end

  before do
    Baseline::Workloads::Registry.reset!
    Baseline.configuration = Baseline::Config.default
  end

  def define_sandboxed_example(metadata = { baseline: true }, &block)
    group = RSpec.describe("sandboxed workload", metadata)
    group.it("does something measurable", &block)
    group.run(RSpec::Core::NullReporter)
    group
  end

  it "discovers a :baseline-tagged example as a workload" do
    define_sandboxed_example { 1 + 1 }

    Baseline::RSpec::Discovery.call

    expect(Baseline.registry.ids.size).to eq(1)
  end

  it "does not register examples without :baseline metadata" do
    define_sandboxed_example({}) { 1 + 1 }

    Baseline::RSpec::Discovery.call

    expect(Baseline.registry.ids).to be_empty
  end

  it "runs the discovered workload repeatedly and serializes a completed result" do
    calls = 0
    define_sandboxed_example { calls += 1 } # runs the example once via group.run, as the initial RSpec pass

    Baseline::RSpec::Discovery.call
    workload = Baseline.registry.first
    workload_config = Baseline.configuration.execution_defaults

    result = Baseline::Execution::Runner.new(workload).call
    run_result = Baseline::Serialization::RunResult.build([result])

    initial_rspec_run = 1
    expect(calls).to eq(workload_config[:samples] + workload_config[:warmup] + initial_rspec_run)
    expect(run_result["workloads"].first["status"]).to eq("completed")
    expect(run_result["workloads"].first["samples"].size).to eq(workload_config[:samples])
    expect(run_result["workloads"].first["summary"]["duration_ns"]).to include("median")
  end

  it "reports a failing example's workload as an execution error" do
    define_sandboxed_example { raise "workload failed" }

    Baseline::RSpec::Discovery.call
    workload = Baseline.registry.first

    result = Baseline::Execution::Runner.new(workload).call

    expect(result["status"]).to eq("error")
    expect(result["error"]).to match(/workload failed/)
  end

  it "honors an explicit id override in the :baseline metadata" do
    define_sandboxed_example(baseline: { id: "custom-id" }) { 1 }

    Baseline::RSpec::Discovery.call

    expect(Baseline.registry.ids).to eq(["custom-id"])
  end

  it "raises a configuration error when two examples share an explicit id" do
    define_sandboxed_example(baseline: { id: "same-id" }) { 1 }
    define_sandboxed_example(baseline: { id: "same-id" }) { 2 }

    expect { Baseline::RSpec::Discovery.call }.to raise_error(Baseline::WorkloadError, /duplicate/i)
  end
end
