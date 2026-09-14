# frozen_string_literal: true

require "perfgate/cli/run_command"
require "perfgate/workloads/workload"

RSpec.describe Perfgate::CLI::RunCommand do
  before { Perfgate.registry.clear }
  after { Perfgate.registry.clear }

  def workload(id)
    Perfgate::Workloads::Workload.new(id: id, samples: 3, warmup: 0) { nil }
  end

  it "applies seed, profile, and policy overrides to the effective configuration" do
    command = described_class.new(%w[--seed 77 --profile pull-request --fail-on warn])
    command.send(:parse_options!)

    config = command.send(:load_configuration)

    expect(config.execution_seed).to eq(77)
    expect(config.dig(:profile)).to eq("pull-request")
    expect(config.policy[:fail_on]).to eq("warn")
  end

  it "filters workloads with --only and randomizes them reproducibly from the configured seed" do
    %w[checkout.create checkout.show invoice.create].each { |id| Perfgate.registry.register(workload(id)) }
    command = described_class.new(%w[--only checkout.* --seed 77])
    command.send(:parse_options!)
    config = command.send(:load_configuration)
    config.to_h[:execution][:order] = "random"

    first = command.send(:selected_workloads, config).map(&:id)
    second = command.send(:selected_workloads, config).map(&:id)

    expect(first).to contain_exactly("checkout.create", "checkout.show")
    expect(second).to eq(first)
  end

  it "honors fail_fast after an execution error" do
    config = Perfgate::Config.default
    config.to_h[:execution][:fail_fast] = true
    workloads = [workload("one"), workload("two")]
    runner = instance_double(Perfgate::Execution::ProcessRunner, call: { "status" => "error" })
    allow(Perfgate::Execution::ProcessRunner).to receive(:new).and_return(runner)

    results = described_class.new([]).send(:execute_workloads, workloads, config)

    expect(results.size).to eq(1)
    expect(Perfgate::Execution::ProcessRunner).to have_received(:new).once
  end
end
