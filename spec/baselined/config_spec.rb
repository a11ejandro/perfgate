# frozen_string_literal: true

require "tmpdir"

RSpec.describe Baselined::Config do
  describe ".default" do
    it "matches the defaults documented in the spec" do
      config = described_class.default

      expect(config.execution_samples).to eq(8)
      expect(config.execution_warmup).to eq(2)
      expect(config.storage_path).to eq(".baselined")
    end

    it "only includes metrics that default to enabled" do
      config = described_class.default

      expect(config.enabled_metrics).to contain_exactly(:duration, :sql_count, :sql_duration, :allocations, :gc)
    end

    it "returns a config independent from other instances (no shared mutable state)" do
      described_class.default.to_h[:execution][:samples] = 999

      expect(described_class.default.execution_samples).to eq(8)
    end
  end

  describe ".load" do
    it "falls back to defaults when the file does not exist" do
      config = described_class.load("/nonexistent/baseline.yml")

      expect(config.execution_samples).to eq(8)
    end

    it "merges user overrides on top of the defaults" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "baselined.yml")
        File.write(path, <<~YAML)
          version: 1
          execution:
            samples: 12
        YAML

        config = described_class.load(path)

        expect(config.execution_samples).to eq(12)
        expect(config.execution_warmup).to eq(2) # untouched default
      end
    end

    it "rejects unknown top-level keys" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "baselined.yml")
        File.write(path, "not_a_real_key: true\n")

        expect { described_class.load(path) }.to raise_error(Baselined::ConfigurationError, /unknown configuration key/)
      end
    end

    it "rejects unknown nested keys" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "baselined.yml")
        File.write(path, "execution:\n  bogus: true\n")

        expect { described_class.load(path) }.to raise_error(Baselined::ConfigurationError, /execution\.bogus/)
      end
    end

    it "rejects a samples count below the spec's minimum of 3" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "baselined.yml")
        File.write(path, "execution:\n  samples: 2\n")

        expect { described_class.load(path) }.to raise_error(Baselined::ConfigurationError, /samples/)
      end
    end

    it "rejects an unsupported configuration version" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "baselined.yml")
        File.write(path, "version: 2\n")

        expect { described_class.load(path) }.to raise_error(Baselined::ConfigurationError, /version/)
      end
    end

    it "applies BASELINE_-prefixed environment variable overrides" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "baselined.yml")
        File.write(path, "version: 1\n")

        with_env("BASELINED_EXECUTION_SAMPLES" => "15") do
          config = described_class.load(path)
          expect(config.execution_samples).to eq(15)
        end
      end
    end
  end

  def with_env(overrides)
    original = ENV.to_hash
    overrides.each { |k, v| ENV[k] = v }
    yield
  ensure
    ENV.replace(original)
  end
end
