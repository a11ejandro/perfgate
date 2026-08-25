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

      expect(result).to eq("status" => "pass", "exit_code" => 0)
    end

    it "warns with exit code 0 when the comparison warned under the default fail_on policy" do
      result = described_class.evaluate(comparison_result: comparison("warn"), config: config)

      expect(result).to eq("status" => "warn", "exit_code" => 0)
    end

    it "escalates a warn to a fail with exit code 1 when fail_on is configured as warn" do
      config.to_h[:policy][:fail_on] = "warn"

      result = described_class.evaluate(comparison_result: comparison("warn"), config: config)

      expect(result).to eq("status" => "fail", "exit_code" => 1)
    end

    it "fails with exit code 1 when the comparison failed" do
      result = described_class.evaluate(comparison_result: comparison("fail"), config: config)

      expect(result).to eq("status" => "fail", "exit_code" => 1)
    end

    it "warns with exit code 0 for an incompatible baseline under the default non-strict policy" do
      result = described_class.evaluate(comparison_result: comparison("incompatible"), config: config)

      expect(result).to eq("status" => "warn", "exit_code" => 0)
    end

    it "reports incomparable with exit code 5 for an incompatible baseline under a strict policy" do
      config.to_h[:policy][:incompatible] = "fail"

      result = described_class.evaluate(comparison_result: comparison("incompatible"), config: config)

      expect(result).to eq("status" => "incomparable", "exit_code" => 5)
    end

    it "escalates a new workload to a fail when new_workload policy is strict" do
      config.to_h[:policy][:new_workload] = "fail"
      workloads = [{ "id" => "w1", "decision" => "new_workload" }]

      result = described_class.evaluate(comparison_result: comparison("warn", workloads: workloads), config: config)

      expect(result).to eq("status" => "fail", "exit_code" => 1)
    end

    it "escalates a removed workload to a fail when removed_workload policy is strict" do
      config.to_h[:policy][:removed_workload] = "fail"
      workloads = [{ "id" => "w1", "decision" => "removed_workload" }]

      result = described_class.evaluate(comparison_result: comparison("warn", workloads: workloads), config: config)

      expect(result).to eq("status" => "fail", "exit_code" => 1)
    end

    it "does not escalate a new workload when new_workload policy is the default warn" do
      workloads = [{ "id" => "w1", "decision" => "new_workload" }]

      result = described_class.evaluate(comparison_result: comparison("warn", workloads: workloads), config: config)

      expect(result).to eq("status" => "warn", "exit_code" => 0)
    end
  end

  describe ".evaluate_missing_baseline" do
    it "warns with exit code 0 under the default non-strict policy" do
      result = described_class.evaluate_missing_baseline(config: config)

      expect(result).to eq("status" => "warn", "exit_code" => 0)
    end

    it "fails with exit code 4 under a strict missing_baseline policy" do
      config.to_h[:policy][:missing_baseline] = "fail"

      result = described_class.evaluate_missing_baseline(config: config)

      expect(result).to eq("status" => "missing_baseline", "exit_code" => 4)
    end
  end
end
