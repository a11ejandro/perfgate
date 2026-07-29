# frozen_string_literal: true

require "baseline/report/console"

RSpec.describe Baseline::Report::Console do
  let(:comparison_result) do
    {
      "baseline_run_id" => "base-run-id",
      "candidate_run_id" => "cand-run-id",
      "compatibility" => { "status" => "compatible" },
      "workloads" => [
        {
          "id" => "checkout.create_order",
          "decision" => "fail",
          "metrics" => {
            "duration" => { "baseline_median" => 281_000_000, "candidate_median" => 337_000_000,
                            "change_percent" => 19.9, "decision" => "fail" },
            "sql_count" => { "baseline_median" => 14, "candidate_median" => 19, "change_percent" => 35.7,
                             "decision" => "fail" }
          },
          "diagnostics" => ["SQL query count increased by 5."]
        }
      ]
    }
  end
  let(:policy_result) { { "status" => "fail", "exit_code" => 1 } }

  describe ".render" do
    subject(:console) { described_class.render(comparison_result: comparison_result, policy_result: policy_result) }

    it "states the overall decision and run identities" do
      expect(console).to include("Overall: FAIL")
      expect(console).to include("Baseline: base-run-id")
      expect(console).to include("Candidate: cand-run-id")
    end

    it "marks a failing workload with a cross" do
      expect(console).to include("\u2717 checkout.create_order")
    end

    it "marks a passing workload with a check" do
      comparison_result["workloads"].first["decision"] = "pass"

      expect(console).to include("\u2713 checkout.create_order")
    end

    it "formats duration metrics in milliseconds" do
      expect(console).to match(/Duration\s+281 ms . 337 ms\s+\+19\.9%\s+FAIL/)
    end

    it "leaves count metrics unconverted" do
      expect(console).to match(/SQL queries\s+14 . 19\s+\+35\.7%\s+FAIL/)
    end

    it "prints a likely-signal line with the workload's diagnostics" do
      expect(console).to include("Likely signal:").and include("SQL query count increased by 5.")
    end

    it "states the compatibility status" do
      expect(console).to include("Compatibility: compatible")
    end
  end
end
