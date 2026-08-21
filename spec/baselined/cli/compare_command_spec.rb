# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require "baselined/cli/compare_command"
require "baselined/serialization/run_result"
require "baselined/statistics/summary"

RSpec.describe Baselined::CLI::CompareCommand do
  around do |example|
    Dir.mktmpdir { |dir| @tmp = dir and example.run }
  end

  def write_run(dir, samples)
    workload_result = {
      "id" => "checkout_flow", "status" => "completed", "error" => nil,
      "definition_hash" => "sha256:same", "samples" => samples.map { |v| { "duration_ns" => v } }
    }
    run_result = Baselined::Serialization::RunResult.build([workload_result])

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
    expect(Dir.children(comparisons_dir).size).to eq(1)
  end

  it "exits 1 when the candidate has a seeded regression" do
    baseline_dir = write_run(File.join(@tmp, "base"), [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map do |v|
      v * 100_000
    end)
    candidate_dir = write_run(File.join(@tmp, "cand"), [1280, 1320, 1290, 1310, 1300, 1330, 1270, 1315].map do |v|
      v * 100_000
    end)

    exit_code = described_class.new(
      ["--baseline", baseline_dir, "--candidate", candidate_dir, "--output", File.join(@tmp, "output")]
    ).call

    expect(exit_code).to eq(1)
  end

  it "raises a configuration error when --candidate is missing" do
    baseline_dir = write_run(File.join(@tmp, "base"), [1000])

    expect { described_class.new(["--baseline", baseline_dir]).call }
      .to raise_error(Baselined::ConfigurationError, /requires both/)
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
    end.to output(/## Baseline Performance Assurance/).to_stdout
  end
end
