# frozen_string_literal: true

require "perfgate/fingerprints/components"

RSpec.describe Perfgate::Fingerprints::Components do
  describe ".collect" do
    it "reports the running ruby engine and version" do
      components = described_class.collect

      expect(components["ruby_engine"]).to eq(RUBY_ENGINE)
      expect(components["ruby_version"]).to eq(RUBY_VERSION)
    end

    it "hashes the dataset fingerprint rather than storing it raw" do
      config = Perfgate::Config.default
      config.dataset_fingerprint = -> { "secret-fixture-set-v3" }

      dataset_hash = described_class.collect(config: config)["dataset_hash"]

      expect(dataset_hash).to start_with("sha256:")
      expect(dataset_hash).not_to include("secret-fixture-set-v3")
    end

    it "produces the same dataset hash for the same underlying value" do
      config = Perfgate::Config.default
      config.dataset_fingerprint = -> { "v1" }

      expect(described_class.collect(config: config)["dataset_hash"])
        .to eq(described_class.collect(config: config)["dataset_hash"])
    end


    it "normalizes PostgreSQL's numeric server version to a major version" do
      connection = instance_double("ActiveRecord connection", adapter_name: "PostgreSQL", database_version: 170_010)
      stub_const("ActiveRecord::Base", class_double("ActiveRecord::Base", connection: connection))

      expect(described_class.database_version_major).to eq("17")
    end
  end
end
