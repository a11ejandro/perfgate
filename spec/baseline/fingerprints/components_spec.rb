# frozen_string_literal: true

require "baseline/fingerprints/components"

RSpec.describe Baseline::Fingerprints::Components do
  describe ".collect" do
    it "reports the running ruby engine and version" do
      components = described_class.collect

      expect(components["ruby_engine"]).to eq(RUBY_ENGINE)
      expect(components["ruby_version"]).to eq(RUBY_VERSION)
    end

    it "hashes the dataset fingerprint rather than storing it raw" do
      config = Baseline::Config.default
      config.dataset_fingerprint = -> { "secret-fixture-set-v3" }

      dataset_hash = described_class.collect(config: config)["dataset_hash"]

      expect(dataset_hash).to start_with("sha256:")
      expect(dataset_hash).not_to include("secret-fixture-set-v3")
    end

    it "produces the same dataset hash for the same underlying value" do
      config = Baseline::Config.default
      config.dataset_fingerprint = -> { "v1" }

      expect(described_class.collect(config: config)["dataset_hash"])
        .to eq(described_class.collect(config: config)["dataset_hash"])
    end
  end
end
