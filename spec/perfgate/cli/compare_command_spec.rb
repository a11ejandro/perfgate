# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require "perfgate/cli/compare_command"
require "perfgate/serialization/run_result"
require "perfgate/statistics/summary"

RSpec.describe Perfgate::CLI::CompareCommand do
  before do
    allow(Perfgate::Fingerprints::Components).to receive(:collect).and_return(methodology_fingerprint)
  end

  around do |example|
    Dir.mktmpdir { |dir| @tmp = dir and example.run }
  end

  def write_run(dir, samples)
    workload_result = {
      "id" => "checkout_flow", "status" => "completed", "error" => nil,
      "definition_hash" => "sha256:same", "assurance" => methodology_assurance,
      "source" => methodology_source,
      "samples" => samples.map { |v| { "duration_ns" => v } }
    }
    run_result = Perfgate::Serialization::RunResult.build([workload_result])

    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "run.json"), JSON.pretty_generate(run_result))
    dir
  end

  it "writes a comparison document and exits 0 for a passing comparison" do
    baseline_dir = write_run(File.join(@tmp, "base"), [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map do |v|
      v * 100_000
    end)
    candidate_dir = write_run(File.join(@tmp, "cand"), [985, 1025, 995, 1005, 1000, 1035, 975, 1010].map do |v|
      v * 100_000
    end)

    exit_code = described_class.new(
      ["--baseline", baseline_dir, "--candidate", candidate_dir, "--output", File.join(@tmp, "output")]
    ).call

    expect(exit_code).to eq(0)
    comparisons_dir = File.join(@tmp, "output", "comparisons")
    expect(Dir.glob(File.join(comparisons_dir, "*.json")).size).to eq(1)
    expect(Dir.glob(File.join(comparisons_dir, "*.sha256")).size).to eq(1)
  end

  it "exits 1 when the candidate has a seeded regression" do
    config_path = File.join(@tmp, "perfgate.yml")
    File.write(config_path, "policy:\n  mode: blocking\n")
    baseline_dir = write_run(File.join(@tmp, "base"), [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map do |v|
      v * 100_000
    end)
    candidate_dir = write_run(File.join(@tmp, "cand"), [1280, 1320, 1290, 1310, 1300, 1330, 1270, 1315].map do |v|
      v * 100_000
    end)

    exit_code = described_class.new(
      ["--config", config_path, "--baseline", baseline_dir, "--candidate", candidate_dir,
       "--output", File.join(@tmp, "output")]
    ).call

    expect(exit_code).to eq(1)
  end

  it "raises a configuration error when --candidate is missing" do
    baseline_dir = write_run(File.join(@tmp, "base"), [1000])

    expect { described_class.new(["--baseline", baseline_dir]).call }
      .to raise_error(Perfgate::ConfigurationError, /requires both/)
  end

  it "prints a Markdown report when --format markdown is given" do
    baseline_dir = write_run(File.join(@tmp, "base"), [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map do |v|
      v * 100_000
    end)
    candidate_dir = write_run(File.join(@tmp, "cand"), [985, 1025, 995, 1005, 1000, 1035, 975, 1010].map do |v|
      v * 100_000
    end)

    expect do
      described_class.new(
        ["--baseline", baseline_dir, "--candidate", candidate_dir, "--output", File.join(@tmp, "output"),
         "--format", "markdown"]
      ).call
    end.to output(/## Perfgate Performance Assurance/).to_stdout
  end
end
