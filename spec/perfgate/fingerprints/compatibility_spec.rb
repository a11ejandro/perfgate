# frozen_string_literal: true

require "perfgate/fingerprints/compatibility"

RSpec.describe Perfgate::Fingerprints::Compatibility do
  let(:config) { Perfgate::Config.default }

  let(:base_components) do
    methodology_fingerprint
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

    it "is incompatible when required provenance is missing from both runs" do
      components = methodology_fingerprint("dataset_hash" => nil)

      result = described_class.evaluate(baseline_components: components, candidate_components: components,
                                        config: config)

      expect(result["status"]).to eq("incompatible")
      expect(result["differences"]).to include(hash_including("field" => "dataset_hash", "reason" => "missing"))
    end
  end
end
