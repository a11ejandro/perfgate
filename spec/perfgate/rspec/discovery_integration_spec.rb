# frozen_string_literal: true

require "rspec/core/sandbox"
require "perfgate/rspec"

# Exercises the exit criterion for Milestone 1 (spec section 28): "one
# workload can be run repeatedly and serialized". Uses RSpec::Core::Sandbox
# so a nested, `:baseline`-tagged example group can be defined and run
# without disturbing the real RSpec::Core::World running this very spec.
RSpec.describe "Baseline RSpec integration" do
  around do |example|
    RSpec::Core::Sandbox.sandboxed { example.run }
  end

  before do
    Perfgate::Workloads::Registry.reset!
    Perfgate.configuration = Perfgate::Config.default
  end

  def define_sandboxed_example(metadata = { perfgate: true }, &block)
    group = RSpec.describe("sandboxed workload", metadata)
    group.it("does something measurable", &block)
    group.run(RSpec::Core::NullReporter)
    group
  end

  it "discovers a :baseline-tagged example as a workload" do
    define_sandboxed_example { 1 + 1 }

    Perfgate::RSpec::Discovery.call

    expect(Perfgate.registry.ids.size).to eq(1)
  end

  it "does not register examples without :baseline metadata" do
    define_sandboxed_example({}) { 1 + 1 }

    Perfgate::RSpec::Discovery.call

    expect(Perfgate.registry.ids).to be_empty
  end

  it "runs the discovered workload repeatedly and serializes a completed result" do
    calls = 0
    define_sandboxed_example { calls += 1 } # runs the example once via group.run, as the initial RSpec pass

    Perfgate::RSpec::Discovery.call
    workload = Perfgate.registry.first
    workload_config = Perfgate.configuration.execution_defaults

    result = Perfgate::Execution::Runner.new(workload).call
    run_result = Perfgate::Serialization::RunResult.build([result])

    initial_rspec_run = 1
    expect(calls).to eq(workload_config[:samples] + workload_config[:warmup] + initial_rspec_run)
    expect(run_result["workloads"].first["status"]).to eq("completed")
    expect(run_result["workloads"].first["samples"].size).to eq(workload_config[:samples])
    expect(run_result["workloads"].first["summary"]["duration_ns"]).to include("median")
  end

  it "reports a failing example's workload as an execution error" do
    define_sandboxed_example { raise "workload failed" }

    Perfgate::RSpec::Discovery.call
    workload = Perfgate.registry.first

    result = Perfgate::Execution::Runner.new(workload).call

    expect(result["status"]).to eq("error")
    expect(result["error"]).to match(/workload failed/)
  end

  it "honors an explicit id override in the :baseline metadata" do
    define_sandboxed_example(perfgate: { id: "custom-id" }) { 1 }

    Perfgate::RSpec::Discovery.call

    expect(Perfgate.registry.ids).to eq(["custom-id"])
  end

  it "raises a configuration error when two examples share an explicit id" do
    define_sandboxed_example(perfgate: { id: "same-id" }) { 1 }
    define_sandboxed_example(perfgate: { id: "same-id" }) { 2 }

    expect { Perfgate::RSpec::Discovery.call }.to raise_error(Perfgate::WorkloadError, /duplicate/i)
  end
end
