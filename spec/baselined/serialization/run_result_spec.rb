# frozen_string_literal: true

require "baselined/serialization/run_result"

RSpec.describe Baselined::Serialization::RunResult do
  describe ".build" do
    it "wraps workload results with schema_version, run_id, and created_at" do
      result = described_class.build([])

      expect(result["schema_version"]).to eq(1)
      expect(result["run_id"]).to match(/\A[0-9a-f-]{36}\z/)
      expect(Time.iso8601(result["created_at"])).to be_a(Time)
      expect(result["workloads"]).to eq([])
    end

    it "generates a distinct run_id on each call" do
      first = described_class.build([])
      second = described_class.build([])

      expect(first["run_id"]).not_to eq(second["run_id"])
    end

    it "attaches a duration summary computed from the workload's samples" do
      workload_result = {
        "id" => "spec/foo_spec.rb:does a thing",
        "status" => "completed",
        "error" => nil,
        "samples" => [{ "duration_ns" => 100 }, { "duration_ns" => 200 }]
      }

      built = described_class.build([workload_result])["workloads"].first

      expect(built["id"]).to eq(workload_result["id"])
      expect(built["summary"]["duration_ns"]["mean"]).to eq(150)
    end

    it "attaches a summary block for every metric key present in the samples" do
      workload_result = {
        "id" => "spec/foo_spec.rb:does a thing",
        "status" => "completed",
        "error" => nil,
        "samples" => [
          { "duration_ns" => 100, "sql_count" => 2, "allocations" => 10 },
          { "duration_ns" => 200, "sql_count" => 4, "allocations" => 20 }
        ]
      }

      summary = described_class.build([workload_result])["workloads"].first["summary"]

      expect(summary.keys).to contain_exactly("duration_ns", "sql_count", "allocations")
      expect(summary["sql_count"]["mean"]).to eq(3)
    end

    it "attaches a fingerprint block describing the run environment" do
      result = described_class.build([])

      expect(result["fingerprint"]).to be_a(Hash)
      expect(result["fingerprint"]["ruby_engine"]).to eq(RUBY_ENGINE)
    end

    it "carries through a workload's definition_hash when present" do
      workload_result = {
        "id" => "spec/foo_spec.rb:does a thing", "status" => "completed", "error" => nil,
        "samples" => [{ "duration_ns" => 100 }], "definition_hash" => "sha256:abc"
      }

      built = described_class.build([workload_result])["workloads"].first

      expect(built["definition_hash"]).to eq("sha256:abc")
    end

    it "omits the summary for a workload with no samples" do
      workload_result = { "id" => "errored", "status" => "error", "error" => "boom", "samples" => [] }

      built = described_class.build([workload_result])["workloads"].first

      expect(built["summary"]).to eq({})
      expect(built["error"]).to eq("boom")
    end
  end
end
