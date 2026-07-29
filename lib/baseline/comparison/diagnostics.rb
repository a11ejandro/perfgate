# frozen_string_literal: true

module Baseline
  module Comparison
    # Simple, deterministic diagnostic rules (spec 20.3). These exist to
    # point a reader at a likely explanation for a regression, never to
    # claim a source-code root cause: "SQL query count increased by 5"
    # is a fact about the sample data, not a guess about which line of
    # code changed.
    module Diagnostics
      module_function

      def for_workload(metrics)
        [
          sql_count_rule(metrics),
          sql_duration_without_count_rule(metrics),
          allocations_rule(metrics),
          duration_without_resource_change_rule(metrics),
          *noise_rules(metrics)
        ].compact
      end

      def environment_changed_rules(compatibility)
        return [] if compatibility["status"] == "compatible"

        compatibility.fetch("differences", []).map do |difference|
          "Environment changed: #{difference["field"]} (#{difference["severity"]})."
        end
      end

      def regressed?(metric_result)
        metric_result && metric_result["decision"] != "pass" && (metric_result["absolute_change"] || 0).positive?
      end

      def sql_count_rule(metrics)
        metric = metrics["sql_count"]
        return nil unless regressed?(metric)

        "SQL query count increased by #{metric["absolute_change"].to_i}."
      end

      def sql_duration_without_count_rule(metrics)
        return nil unless regressed?(metrics["sql_duration"]) && !regressed?(metrics["sql_count"])

        "SQL duration increased without a corresponding increase in query count."
      end

      def allocations_rule(metrics)
        metric = metrics["allocations"]
        return nil unless regressed?(metric)

        "Allocations increased by #{metric["change_percent"]}%."
      end

      def duration_without_resource_change_rule(metrics)
        return nil unless regressed?(metrics["duration"])

        resource_metrics = metrics.values_at("sql_count", "sql_duration", "allocations").compact
        return nil if resource_metrics.empty? || resource_metrics.any? { |metric| metric["decision"] != "pass" }

        "Duration increased while SQL and allocation metrics remained stable."
      end

      def noise_rules(metrics)
        metrics.select { |_name, metric| metric["noisy"] }
               .map { |name, _metric| "Sample variability is high for #{name}; treat this decision with caution." }
      end
    end
  end
end
