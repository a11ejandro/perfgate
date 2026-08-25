# frozen_string_literal: true

module Perfgate
  module Report
    # Renders the schema_version 1 comparison-result document (plus its
    # Policy::Engine verdict) as the plain-text console summary from
    # spec 20.1: overall decision, run identities, a per-workload/
    # per-metric table with a "likely signal" diagnostic line,
    # compatibility status, and sample counts.
    module Console
      DURATION_METRICS = %w[duration sql_duration].freeze
      METRIC_LABELS = { "duration" => "Duration", "sql_count" => "SQL queries", "sql_duration" => "SQL duration",
                        "allocations" => "Allocations" }.freeze

      module_function

      def render(comparison_result:, policy_result:)
        lines = ["Baseline Performance Assurance", "", "Overall: #{policy_result["status"].upcase}",
                 "Baseline: #{comparison_result["baseline_run_id"]}",
                 "Candidate: #{comparison_result["candidate_run_id"]}", ""]
        comparison_result.fetch("workloads", []).each { |workload| lines.concat(workload_lines(workload)) }
        lines << "Compatibility: #{comparison_result.dig("compatibility", "status")}"
        lines.join("\n")
      end

      def workload_lines(workload)
        marker = workload["decision"] == "pass" ? "\u2713" : "\u2717"
        lines = ["#{marker} #{workload["id"]}"]
        workload["metrics"].each { |name, metric| lines << metric_line(name, metric) }
        lines.concat(diagnostics_lines(workload))
        lines << ""
      end

      def metric_line(name, metric)
        label = METRIC_LABELS.fetch(name, name)
        before = format_value(name, metric["baseline_median"])
        after = format_value(name, metric["candidate_median"])
        change = metric["change_percent"] ? format("%+.1f%%", metric["change_percent"]) : "n/a"
        format("  %<label>-15s %<before>s \u2192 %<after>s   %<change>s   %<decision>s",
               label: label, before: before, after: after, change: change, decision: metric["decision"].upcase)
      end

      def format_value(name, value)
        return "n/a" if value.nil?

        DURATION_METRICS.include?(name) ? format("%.0f ms", value / 1_000_000.0) : value.to_s
      end

      def diagnostics_lines(workload)
        messages = workload["diagnostics"] || []
        return [] if messages.empty?

        ["  Likely signal:"] + messages.map { |message| "    #{message}" }
      end
    end
  end
end
