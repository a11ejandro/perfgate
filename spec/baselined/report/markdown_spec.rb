# frozen_string_literal: true

require "baselined/report/markdown"

RSpec.describe Baselined::Report::Markdown do
  let(:comparison_result) do
    {
      "schema_version" => 1,
      "baseline_run_id" => "base-run-id",
      "candidate_run_id" => "cand-run-id",
      "compatibility" => { "status" => "compatible", "differences" => [] },
      "decision" => "fail",
      "workloads" => [
        {
          "id" => "checkout.create_order",
          "decision" => "fail",
          "metrics" => {
            "duration" => { "metric" => "duration", "baseline_median" => 281_000_000,
                            "candidate_median" => 337_000_000, "change_percent" => 19.9,
                            "decision" => "fail", "noisy" => false },
            "sql_count" => { "metric" => "sql_count", "baseline_median" => 14, "candidate_median" => 19,
                             "change_percent" => 35.7, "decision" => "fail", "noisy" => false }
          },
          "diagnostics" => ["SQL query count increased by 5."]
        }
      ],
      "diagnostics" => []
    }
  end
  let(:policy_result) { { "status" => "fail", "exit_code" => 1 } }

  describe ".render" do
    subject(:markdown) do
      described_class.render(comparison_result: comparison_result, policy_result: policy_result,
                             comparison_path: ".baseline/comparisons/abc.json")
    end

    it "states the overall decision" do
      expect(markdown).to include("**Overall:** FAIL")
    end

    it "identifies the baseline and candidate runs" do
      expect(markdown).to include("base-run-id").and include("cand-run-id")
    end

    it "states the compatibility status" do
      expect(markdown).to include("**Compatibility:** compatible")
    end

    it "renders a table row per workload metric with formatted values" do
      expect(markdown).to include("| checkout.create_order | duration | 281.00ms | 337.00ms | +19.9% | FAIL |")
      expect(markdown).to include("| checkout.create_order | sql_count | 14 | 19 | +35.7% | FAIL |")
    end

    it "surfaces workload diagnostics" do
      expect(markdown).to include("SQL query count increased by 5.")
    end

    it "links to the machine-readable output" do
      expect(markdown).to include(".baseline/comparisons/abc.json")
    end

    it "explains the exit code" do
      expect(markdown).to include("Exit code `1`")
    end

    it "flags a noisy metric" do
      comparison_result["workloads"].first["metrics"]["duration"]["noisy"] = true

      expect(markdown).to include("FAIL ⚠️ noisy")
    end
  end

  describe "with no workloads compared" do
    it "notes that nothing was compared" do
      empty_result = comparison_result.merge("workloads" => [])

      markdown = described_class.render(comparison_result: empty_result, policy_result: policy_result)

      expect(markdown).to include("No workloads were compared")
    end
  end
end
