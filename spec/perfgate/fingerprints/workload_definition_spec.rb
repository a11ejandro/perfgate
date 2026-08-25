# frozen_string_literal: true

require "perfgate/fingerprints/workload_definition"
require "perfgate/workloads/workload"

RSpec.describe Perfgate::Fingerprints::WorkloadDefinition do
  describe ".hash_for" do
    def workload(id: "checkout_flow", samples: 8, warmup: 2, metrics: %i[duration sql_count])
      Perfgate::Workloads::Workload.new(id: id, samples: samples, warmup: warmup, metrics: metrics) { nil }
    end

    it "returns a stable sha256 fingerprint for identical definitions" do
      expect(described_class.hash_for(workload)).to eq(described_class.hash_for(workload))
      expect(described_class.hash_for(workload)).to start_with("sha256:")
    end

    it "changes when the sample count changes" do
      expect(described_class.hash_for(workload(samples: 8))).not_to eq(described_class.hash_for(workload(samples: 16)))
    end

    it "changes when the enabled metrics change" do
      expect(described_class.hash_for(workload(metrics: %i[duration])))
        .not_to eq(described_class.hash_for(workload(metrics: %i[duration sql_count])))
    end

    it "is insensitive to the order metrics were declared in" do
      expect(described_class.hash_for(workload(metrics: %i[duration sql_count])))
        .to eq(described_class.hash_for(workload(metrics: %i[sql_count duration])))
    end
  end
end
