# frozen_string_literal: true

require "perfgate/comparison/engine"
require "perfgate/config"
require "perfgate/statistics/summary"

RSpec.describe Perfgate::Comparison::Engine do
  let(:config) { Perfgate::Config.default }

  let(:fingerprint) do
    {
      "ruby_engine" => "ruby", "ruby_version" => "3.2.2", "rails_version" => "7.1.0",
      "baseline_version_major" => "0", "database_adapter" => "SQLite", "database_version_major" => "3",
      "dataset_hash" => "sha256:abc", "operating_system" => "darwin23", "cpu_model" => "Apple M2",
      "cpu_count" => "8", "memory_bytes" => nil, "ci_provider" => "github_actions",
      "runner_image" => "ubuntu-22.04", "dependency_lock_hash" => "sha256:def"
    }
  end

  def workload(id:, samples:, definition_hash: "sha256:same")
    duration_samples = samples.map { |v| { "duration_ns" => v } }
    {
      "id" => id, "status" => "completed", "error" => nil, "definition_hash" => definition_hash,
      "samples" => duration_samples,
      "summary" => { "duration_ns" => Perfgate::Statistics::Summary.call(samples) }
    }
  end

  def run(run_id:, workloads:, fingerprint_overrides: {})
    {
      "schema_version" => 1, "run_id" => run_id, "created_at" => "2024-01-01T00:00:00Z",
      "fingerprint" => fingerprint.merge(fingerprint_overrides), "workloads" => workloads
    }
  end

  let(:stable_samples) { [980, 1020, 990, 1010, 1000, 1030, 970, 1015].map { |v| v * 100_000 } }
  let(:regressed_samples) { stable_samples.map { |v| v + (300 * 100_000) } }

  describe ".compare" do
    it "marks the runs incompatible without computing any per-workload decision when a strict field changed" do
      baseline_run = run(run_id: "base", workloads: [workload(id: "w1", samples: stable_samples)])
      candidate_run = run(run_id: "cand", workloads: [workload(id: "w1", samples: stable_samples)],
                          fingerprint_overrides: { "ruby_version" => "3.3.0" })

      result = described_class.compare(baseline_run: baseline_run, candidate_run: candidate_run, config: config)

      expect(result["compatibility"]["status"]).to eq("incompatible")
      expect(result["decision"]).to eq("incompatible")
      expect(result["workloads"]).to eq([])
    end

    it "passes a compatible run pair with no meaningful regression" do
      baseline_run = run(run_id: "base", workloads: [workload(id: "w1", samples: stable_samples)])
      candidate_run = run(run_id: "cand", workloads: [workload(id: "w1", samples: stable_samples)])

      result = described_class.compare(baseline_run: baseline_run, candidate_run: candidate_run, config: config)

      expect(result["compatibility"]["status"]).to eq("compatible")
      expect(result["decision"]).to eq("pass")
      expect(result["workloads"].first["decision"]).to eq("pass")
    end

    it "fails the run when a workload has a seeded duration regression" do
      baseline_run = run(run_id: "base", workloads: [workload(id: "w1", samples: stable_samples)])
      candidate_run = run(run_id: "cand", workloads: [workload(id: "w1", samples: regressed_samples)])

      result = described_class.compare(baseline_run: baseline_run, candidate_run: candidate_run, config: config)

      expect(result["decision"]).to eq("fail")
      expect(result["workloads"].first["metrics"]["duration"]["decision"]).to eq("fail")
    end

    it "marks a workload incomparable when its definition_hash changed, without comparing its metrics" do
      baseline_run = run(run_id: "base",
                         workloads: [workload(id: "w1", samples: stable_samples, definition_hash: "sha256:old")])
      candidate_run = run(run_id: "cand",
                          workloads: [workload(id: "w1", samples: regressed_samples, definition_hash: "sha256:new")])

      result = described_class.compare(baseline_run: baseline_run, candidate_run: candidate_run, config: config)

      workload_result = result["workloads"].first
      expect(workload_result["decision"]).to eq("incomparable")
      expect(workload_result["metrics"]).to eq({})
    end

    it "flags a workload missing from the baseline as new" do
      baseline_run = run(run_id: "base", workloads: [])
      candidate_run = run(run_id: "cand", workloads: [workload(id: "w1", samples: stable_samples)])

      result = described_class.compare(baseline_run: baseline_run, candidate_run: candidate_run, config: config)

      expect(result["workloads"].first["decision"]).to eq("new_workload")
    end

    it "flags a workload missing from the candidate as removed_workload" do
      baseline_run = run(run_id: "base", workloads: [workload(id: "w1", samples: stable_samples)])
      candidate_run = run(run_id: "cand", workloads: [])

      result = described_class.compare(baseline_run: baseline_run, candidate_run: candidate_run, config: config)

      expect(result["workloads"].first["decision"]).to eq("removed_workload")
    end
  end
end
