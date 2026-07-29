# frozen_string_literal: true

require "baseline/comparison/engine"
require "baseline/policy/engine"
require "baseline/config"
require "baseline/statistics/summary"

# Milestone 3's exit criterion (spec roadmap): "seeded regressions produce
# explainable decisions and incompatible runs never silently compare."
# These specs seed synthetic sample distributions with a known regression
# (or lack thereof) and check the full comparison -> policy -> exit code
# pipeline behaves as a human reading the roadmap would expect.
RSpec.describe "regression injection" do
  let(:config) { Baseline::Config.default }

  let(:fingerprint) do
    {
      "ruby_engine" => "ruby", "ruby_version" => "3.2.2", "rails_version" => "7.1.0",
      "baseline_version_major" => "0", "database_adapter" => "SQLite", "database_version_major" => "3",
      "dataset_hash" => "sha256:abc", "operating_system" => "darwin23", "cpu_model" => "Apple M2",
      "cpu_count" => "8", "memory_bytes" => nil, "ci_provider" => "github_actions",
      "runner_image" => "ubuntu-22.04", "dependency_lock_hash" => "sha256:def"
    }
  end

  def workload(id:, duration:, sql_count: nil, definition_hash: "sha256:same")
    samples = duration.zip(sql_count || Array.new(duration.size)).map do |duration_ns, count|
      count.nil? ? { "duration_ns" => duration_ns } : { "duration_ns" => duration_ns, "sql_count" => count }
    end
    summary = { "duration_ns" => Baseline::Statistics::Summary.call(duration) }
    summary["sql_count"] = Baseline::Statistics::Summary.call(sql_count) if sql_count

    { "id" => id, "status" => "completed", "error" => nil, "definition_hash" => definition_hash,
      "samples" => samples, "summary" => summary }
  end

  def run(run_id:, workloads:, fingerprint_overrides: {})
    { "schema_version" => 1, "run_id" => run_id, "created_at" => "2024-01-01T00:00:00Z",
      "fingerprint" => fingerprint.merge(fingerprint_overrides), "workloads" => workloads }
  end

  def compare_and_evaluate(baseline_run, candidate_run)
    comparison_result = Baseline::Comparison::Engine.compare(
      baseline_run: baseline_run, candidate_run: candidate_run, config: config
    )
    policy_result = Baseline::Policy::Engine.evaluate(comparison_result: comparison_result, config: config)
    [comparison_result, policy_result]
  end

  let(:stable_duration) { [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map { |v| v * 100_000 } }

  it "passes a candidate with no meaningful change, with an explainable pass decision" do
    baseline_run = run(run_id: "base", workloads: [workload(id: "checkout", duration: stable_duration)])
    candidate_run = run(run_id: "cand", workloads: [workload(id: "checkout", duration: stable_duration)])

    comparison_result, policy_result = compare_and_evaluate(baseline_run, candidate_run)

    expect(policy_result).to eq("status" => "pass", "exit_code" => 0)
    workload_result = comparison_result["workloads"].first
    expect(workload_result["decision"]).to eq("pass")
    expect(workload_result["metrics"]["duration"]["decision"]).to eq("pass")
  end

  it "fails on a seeded duration regression that is both practically and statistically significant" do
    regressed_duration = stable_duration.map { |v| v + (350 * 100_000) }
    baseline_run = run(run_id: "base", workloads: [workload(id: "checkout", duration: stable_duration)])
    candidate_run = run(run_id: "cand", workloads: [workload(id: "checkout", duration: regressed_duration)])

    comparison_result, policy_result = compare_and_evaluate(baseline_run, candidate_run)

    expect(policy_result).to eq("status" => "fail", "exit_code" => 1)
    metric = comparison_result["workloads"].first["metrics"]["duration"]
    expect(metric["decision"]).to eq("fail")
    expect(metric["change_percent"]).to be > 20
  end

  it "fails on a seeded sql_count regression using the deterministic comparison, not statistics" do
    stable_counts = [3, 3, 3, 3, 3, 3, 3, 3]
    regressed_counts = [6, 6, 6, 6, 6, 6, 6, 6]
    baseline_run = run(run_id: "base",
                       workloads: [workload(id: "checkout", duration: stable_duration, sql_count: stable_counts)])
    candidate_run = run(run_id: "cand",
                        workloads: [workload(id: "checkout", duration: stable_duration,
                                             sql_count: regressed_counts)])

    comparison_result, policy_result = compare_and_evaluate(baseline_run, candidate_run)

    expect(policy_result).to eq("status" => "fail", "exit_code" => 1)
    expect(comparison_result["workloads"].first["metrics"]["sql_count"]["decision"]).to eq("fail")
  end

  it "downgrades a noisy would-be regression to warn instead of a hard fail" do
    noisy_baseline = [500, 1500, 600, 1400, 550, 1450, 620, 1380].map { |v| v * 100_000 }
    noisy_candidate = noisy_baseline.map { |v| v + (v * 0.22).round }
    baseline_run = run(run_id: "base", workloads: [workload(id: "checkout", duration: noisy_baseline)])
    candidate_run = run(run_id: "cand", workloads: [workload(id: "checkout", duration: noisy_candidate)])

    comparison_result, policy_result = compare_and_evaluate(baseline_run, candidate_run)

    metric = comparison_result["workloads"].first["metrics"]["duration"]
    expect(metric["decision"]).to eq("warn")
    expect(policy_result).to eq("status" => "warn", "exit_code" => 0)
  end

  it "never silently compares an incompatible run pair, defaulting to a non-blocking warn" do
    baseline_run = run(run_id: "base", workloads: [workload(id: "checkout", duration: stable_duration)])
    candidate_run = run(run_id: "cand", workloads: [workload(id: "checkout", duration: stable_duration)],
                        fingerprint_overrides: { "database_adapter" => "PostgreSQL" })

    comparison_result, policy_result = compare_and_evaluate(baseline_run, candidate_run)

    expect(comparison_result["compatibility"]["status"]).to eq("incompatible")
    expect(comparison_result["workloads"]).to eq([])
    expect(policy_result).to eq("status" => "warn", "exit_code" => 0)
  end

  it "blocks the build with exit code 5 for an incompatible run pair under a strict policy" do
    config.to_h[:policy][:incompatible] = "fail"
    baseline_run = run(run_id: "base", workloads: [workload(id: "checkout", duration: stable_duration)])
    candidate_run = run(run_id: "cand", workloads: [workload(id: "checkout", duration: stable_duration)],
                        fingerprint_overrides: { "database_adapter" => "PostgreSQL" })

    _comparison_result, policy_result = compare_and_evaluate(baseline_run, candidate_run)

    expect(policy_result).to eq("status" => "incomparable", "exit_code" => 5)
  end

  it "flags a workload whose definition changed as incomparable rather than guessing at a decision" do
    regressed_duration = stable_duration.map { |v| v + (350 * 100_000) }
    baseline_run = run(run_id: "base", workloads: [workload(id: "checkout", duration: stable_duration)])
    candidate_run = run(run_id: "cand",
                        workloads: [workload(id: "checkout", duration: regressed_duration,
                                             definition_hash: "sha256:changed")])

    comparison_result, policy_result = compare_and_evaluate(baseline_run, candidate_run)

    expect(comparison_result["workloads"].first["decision"]).to eq("incomparable")
    expect(policy_result).to eq("status" => "warn", "exit_code" => 0)
  end
end
