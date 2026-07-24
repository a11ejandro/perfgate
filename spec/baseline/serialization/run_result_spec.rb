# frozen_string_literal: true

require "baseline/serialization/run_result"

RSpec.describe Baseline::Serialization::RunResult do
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

    it "omits the summary for a workload with no samples" do
      workload_result = { "id" => "errored", "status" => "error", "error" => "boom", "samples" => [] }

      built = described_class.build([workload_result])["workloads"].first

      expect(built["summary"]).to eq({})
      expect(built["error"]).to eq("boom")
    end
  end
end
