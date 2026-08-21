# frozen_string_literal: true

require "baselined/comparison/diagnostics"

RSpec.describe Baselined::Comparison::Diagnostics do
  def metric(decision:, absolute_change: 0, change_percent: 0, noisy: false)
    { "decision" => decision, "absolute_change" => absolute_change, "change_percent" => change_percent,
      "noisy" => noisy }
  end

  describe ".for_workload" do
    it "flags an increased SQL query count" do
      metrics = { "sql_count" => metric(decision: "fail", absolute_change: 5) }

      expect(described_class.for_workload(metrics)).to include("SQL query count increased by 5.")
    end

    it "flags SQL duration increasing without a query count increase" do
      metrics = {
        "sql_duration" => metric(decision: "warn", absolute_change: 20_000_000),
        "sql_count" => metric(decision: "pass")
      }

      expect(described_class.for_workload(metrics))
        .to include("SQL duration increased without a corresponding increase in query count.")
    end

    it "does not raise the sql_duration-without-count diagnostic when sql_count also regressed" do
      metrics = {
        "sql_duration" => metric(decision: "warn", absolute_change: 20_000_000),
        "sql_count" => metric(decision: "fail", absolute_change: 3)
      }

      expect(described_class.for_workload(metrics))
        .not_to include("SQL duration increased without a corresponding increase in query count.")
    end

    it "flags increased allocations" do
      metrics = { "allocations" => metric(decision: "warn", absolute_change: 500, change_percent: 12.5) }

      expect(described_class.for_workload(metrics)).to include("Allocations increased by 12.5%.")
    end

    it "flags a duration regression when resource metrics stayed stable" do
      metrics = {
        "duration" => metric(decision: "fail", absolute_change: 10_000_000),
        "sql_count" => metric(decision: "pass"),
        "sql_duration" => metric(decision: "pass"),
        "allocations" => metric(decision: "pass")
      }

      expect(described_class.for_workload(metrics))
        .to include("Duration increased while SQL and allocation metrics remained stable.")
    end

    it "does not raise the stable-resources diagnostic when a resource metric also regressed" do
      metrics = {
        "duration" => metric(decision: "fail", absolute_change: 10_000_000),
        "sql_count" => metric(decision: "fail", absolute_change: 5)
      }

      expect(described_class.for_workload(metrics))
        .not_to include("Duration increased while SQL and allocation metrics remained stable.")
    end

    it "flags a noisy metric" do
      metrics = { "duration" => metric(decision: "warn", absolute_change: 1, noisy: true) }

      expect(described_class.for_workload(metrics))
        .to include("Sample variability is high for duration; treat this decision with caution.")
    end

    it "returns no diagnostics for a passing workload" do
      metrics = { "duration" => metric(decision: "pass"), "allocations" => metric(decision: "pass") }

      expect(described_class.for_workload(metrics)).to eq([])
    end
  end

  describe ".environment_changed_rules" do
    it "returns no rules for a fully compatible fingerprint" do
      compatibility = { "status" => "compatible", "differences" => [] }

      expect(described_class.environment_changed_rules(compatibility)).to eq([])
    end

    it "describes each informational difference for a compatible_with_warnings fingerprint" do
      compatibility = {
        "status" => "compatible_with_warnings",
        "differences" => [{ "field" => "operating_system", "severity" => "informational" }]
      }

      expect(described_class.environment_changed_rules(compatibility))
        .to eq(["Environment changed: operating_system (informational)."])
    end
  end
end
