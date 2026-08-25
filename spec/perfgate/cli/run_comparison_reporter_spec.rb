# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require "perfgate/cli/run_comparison_reporter"
require "perfgate/serialization/run_result"
require "perfgate/config"

RSpec.describe Perfgate::CLI::RunComparisonReporter do
  around do |example|
    Dir.mktmpdir { |dir| @tmp = dir and example.run }
  end

  def write_run(dir, samples)
    workload_result = {
      "id" => "checkout_flow", "status" => "completed", "error" => nil,
      "definition_hash" => "sha256:same", "samples" => samples.map { |v| { "duration_ns" => v } }
    }
    run_result = Perfgate::Serialization::RunResult.build([workload_result])
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "run.json"), JSON.pretty_generate(run_result))
    run_result
  end

  let(:config) { Perfgate::Config.default }

  it "compares against a reference bundle and writes a summary.md when --format markdown" do
    baseline_dir = File.join(@tmp, "reference")
    write_run(baseline_dir, [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map { |v| v * 100_000 })
    candidate = write_run(File.join(@tmp, "candidate_unused"),
                          [985, 1025, 995, 1005, 1000, 1035, 975, 1010].map { |v| v * 100_000 })
    run_dir = File.join(@tmp, "current")
    FileUtils.mkdir_p(run_dir)

    reporter = described_class.new(reference_path: baseline_dir, output_root: File.join(@tmp, "output"),
                                   format: "markdown")
    exit_code = reporter.call(config: config, run_result: candidate, run_dir: run_dir)

    expect(exit_code).to eq(0)
    summary = File.read(File.join(run_dir, "summary.md"))
    expect(summary).to include("## Baseline Performance Assurance")
  end

  it "treats a missing reference bundle as a missing baseline, not a crash" do
    candidate = write_run(File.join(@tmp, "candidate"), [1000])
    run_dir = File.join(@tmp, "current")
    FileUtils.mkdir_p(run_dir)

    reporter = described_class.new(reference_path: File.join(@tmp, "does-not-exist"),
                                   output_root: File.join(@tmp, "output"), format: "markdown")
    exit_code = reporter.call(config: config, run_result: candidate, run_dir: run_dir)

    expect(exit_code).to eq(0)
    expect(File.read(File.join(run_dir, "summary.md"))).to include("No baseline was found")
  end

  it "exits 1 on a seeded regression and prints the console report by default" do
    baseline_dir = File.join(@tmp, "reference")
    write_run(baseline_dir, [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map { |v| v * 100_000 })
    candidate = write_run(File.join(@tmp, "candidate"),
                          [1280, 1320, 1290, 1310, 1300, 1330, 1270, 1315].map { |v| v * 100_000 })
    run_dir = File.join(@tmp, "current")
    FileUtils.mkdir_p(run_dir)

    reporter = described_class.new(reference_path: baseline_dir, output_root: File.join(@tmp, "output"), format: nil)
    exit_code = nil
    expect { exit_code = reporter.call(config: config, run_result: candidate, run_dir: run_dir) }
      .to output(/Machine-readable result/).to_stdout

    expect(exit_code).to eq(1)
    expect(File.exist?(File.join(run_dir, "summary.md"))).to be(false)
  end
end
