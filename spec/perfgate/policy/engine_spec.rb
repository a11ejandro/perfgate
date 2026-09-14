# frozen_string_literal: true

require "perfgate/policy/engine"
require "perfgate/config"

RSpec.describe Perfgate::Policy::Engine do
  let(:config) { Perfgate::Config.default }

  def comparison(decision, workloads: [])
    { "decision" => decision, "workloads" => workloads }
  end

  describe ".evaluate" do
    it "passes with exit code 0 when the comparison passed" do
      result = described_class.evaluate(comparison_result: comparison("pass"), config: config)

      expect(result).to include("status" => "pass", "exit_code" => 0, "evidence_status" => "pass")
    end

    it "warns with exit code 0 when the comparison warned under the default fail_on policy" do
      result = described_class.evaluate(comparison_result: comparison("warn"), config: config)

      expect(result).to include("status" => "warn", "exit_code" => 0, "evidence_status" => "warn")
    end

    it "escalates a warn to a fail with exit code 1 when fail_on is configured as warn" do
      config.to_h[:policy][:mode] = "blocking"
      config.to_h[:policy][:fail_on] = "warn"

      result = described_class.evaluate(comparison_result: comparison("warn"), config: config)

      expect(result).to include("status" => "fail", "exit_code" => 1, "evidence_status" => "warn")
    end

    it "fails with exit code 1 when the comparison failed" do
      config.to_h[:policy][:mode] = "blocking"
      result = described_class.evaluate(comparison_result: comparison("fail"), config: config)

      expect(result).to include("status" => "fail", "exit_code" => 1, "evidence_status" => "fail")
    end


    it "reports a regression without blocking before direct-gate validation is opted into" do
      result = described_class.evaluate(comparison_result: comparison("fail"), config: config)

      expect(result).to include("status" => "warn", "exit_code" => 0, "evidence_status" => "fail")
      expect(result["rule"]).to include("mode=advisory")
    end

    it "warns with exit code 0 for an incompatible baseline under the default non-strict policy" do
      result = described_class.evaluate(comparison_result: comparison("incompatible"), config: config)

      expect(result).to include("status" => "warn", "exit_code" => 0, "evidence_status" => "incompatible")
    end

    it "reports incomparable with exit code 5 for an incompatible baseline under a strict policy" do
      config.to_h[:policy][:incompatible] = "fail"

      result = described_class.evaluate(comparison_result: comparison("incompatible"), config: config)

      expect(result).to include("status" => "incomparable", "exit_code" => 5,
                                "evidence_status" => "incompatible")
    end

    it "escalates a new workload to a fail when new_workload policy is strict" do
      config.to_h[:policy][:new_workload] = "fail"
      workloads = [{ "id" => "w1", "decision" => "new_workload" }]

      result = described_class.evaluate(comparison_result: comparison("warn", workloads: workloads), config: config)

      expect(result).to include("status" => "fail", "exit_code" => 1, "evidence_status" => "warn")
    end

    it "escalates a removed workload to a fail when removed_workload policy is strict" do
      config.to_h[:policy][:removed_workload] = "fail"
      workloads = [{ "id" => "w1", "decision" => "removed_workload" }]

      result = described_class.evaluate(comparison_result: comparison("warn", workloads: workloads), config: config)

      expect(result).to include("status" => "fail", "exit_code" => 1, "evidence_status" => "warn")
    end

    it "does not escalate a new workload when new_workload policy is the default warn" do
      workloads = [{ "id" => "w1", "decision" => "new_workload" }]

      result = described_class.evaluate(comparison_result: comparison("warn", workloads: workloads), config: config)

      expect(result).to include("status" => "warn", "exit_code" => 0, "evidence_status" => "warn")
    end


    it "returns the execution-error exit code instead of passing an errored workload" do
      workloads = [{ "id" => "w1", "decision" => "inconclusive", "execution_error" => true }]

      result = described_class.evaluate(comparison_result: comparison("inconclusive", workloads: workloads),
                                        config: config)

      expect(result).to include("status" => "execution_error", "exit_code" => 3)
    end

    it "can make inconclusive evidence blocking without relabeling its evidence state" do
      config.to_h[:policy][:inconclusive] = "fail"

      result = described_class.evaluate(comparison_result: comparison("inconclusive"), config: config)

      expect(result).to include("status" => "fail", "exit_code" => 1, "evidence_status" => "inconclusive")
    end
  end

  describe ".evaluate_missing_baseline" do
    it "warns with exit code 0 under the default non-strict policy" do
      result = described_class.evaluate_missing_baseline(config: config)

      expect(result).to include("status" => "warn", "exit_code" => 0, "evidence_status" => "incomparable")
    end

    it "fails with exit code 4 under a strict missing_baseline policy" do
      config.to_h[:policy][:missing_baseline] = "fail"

      result = described_class.evaluate_missing_baseline(config: config)

      expect(result).to include("status" => "missing_baseline", "exit_code" => 4,
                                "evidence_status" => "incomparable")
    end
  end
end
