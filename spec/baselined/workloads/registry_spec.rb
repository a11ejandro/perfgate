# frozen_string_literal: true

RSpec.describe Baselined::Workloads::Registry do
  subject(:registry) { described_class.new }

  let(:workload_a) { Baselined::Workloads::Workload.new(id: "a", samples: 3, warmup: 0, metrics: [:duration]) { 1 } }
  let(:workload_b) { Baselined::Workloads::Workload.new(id: "b", samples: 3, warmup: 0, metrics: [:duration]) { 2 } }

  it "registers and enumerates workloads" do
    registry.register(workload_a)
    registry.register(workload_b)

    expect(registry.map(&:id)).to contain_exactly("a", "b")
  end

  it "rejects a second workload with a duplicate id" do
    registry.register(workload_a)
    duplicate = Baselined::Workloads::Workload.new(id: "a", samples: 3, warmup: 0, metrics: [:duration]) { 3 }

    expect { registry.register(duplicate) }.to raise_error(Baselined::WorkloadError, /duplicate/i)
  end

  describe ".instance" do
    it "returns the same singleton across calls" do
      expect(described_class.instance).to equal(described_class.instance)
    end

    it "resets to an empty registry via .reset!" do
      described_class.instance.register(workload_a)
      described_class.reset!

      expect(described_class.instance.to_a).to be_empty
    end
  end
end
