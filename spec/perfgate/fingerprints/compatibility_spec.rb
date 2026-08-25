# frozen_string_literal: true

require "perfgate/fingerprints/compatibility"

RSpec.describe Perfgate::Fingerprints::Compatibility do
  let(:config) { Perfgate::Config.default }

  let(:base_components) do
    {
      "ruby_engine" => "ruby",
      "ruby_version" => "3.2.2",
      "rails_version" => "7.1.0",
      "baseline_version_major" => "0",
      "database_adapter" => "SQLite",
      "database_version_major" => "3",
      "dataset_hash" => "sha256:abc",
      "operating_system" => "darwin23",
      "cpu_model" => "Apple M2",
      "cpu_count" => "8",
      "memory_bytes" => nil,
      "ci_provider" => "github_actions",
      "runner_image" => "ubuntu-22.04",
      "dependency_lock_hash" => "sha256:def"
    }
  end

  describe ".evaluate" do
    it "is compatible when every component matches" do
      result = described_class.evaluate(baseline_components: base_components, candidate_components: base_components,
                                        config: config)

      expect(result["status"]).to eq("compatible")
      expect(result["differences"]).to be_empty
    end

    it "is incompatible when a strict field differs" do
      candidate = base_components.merge("ruby_version" => "3.3.0")

      result = described_class.evaluate(baseline_components: base_components, candidate_components: candidate,
                                        config: config)

      expect(result["status"]).to eq("incompatible")
      expect(result["differences"]).to include(hash_including("field" => "ruby_version", "severity" => "strict"))
    end

    it "is compatible_with_warnings when only an informational field differs" do
      candidate = base_components.merge("cpu_model" => "Apple M3")

      result = described_class.evaluate(baseline_components: base_components, candidate_components: candidate,
                                        config: config)

      expect(result["status"]).to eq("compatible_with_warnings")
      expect(result["differences"]).to include(hash_including("field" => "cpu_model", "severity" => "informational"))
    end
  end
end
