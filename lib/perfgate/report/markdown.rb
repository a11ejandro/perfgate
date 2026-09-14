# frozen_string_literal: true

module Perfgate
  module Report
    # Renders the schema_version 2 comparison-result document (plus its
    # Policy::Engine verdict) as a Markdown report, per spec 20.2: the
    # overall decision, run identities, compatibility status, a
    # per-workload/per-metric table, noise warnings, diagnostics, a
    # pointer to the machine-readable JSON, and an explanation of the
    # exit code. This is what `perfgate run --format markdown` writes
    # and what the GitHub Actions example appends to the job summary.
    module Markdown
      DURATION_METRICS = %w[duration sql_duration].freeze

      module_function

      def render(comparison_result:, policy_result:, comparison_path: nil)
        [
          header(policy_result),
          identities(comparison_result),
          "**Compatibility:** #{comparison_result.dig("compatibility", "status")}",
          workloads_table(comparison_result),
          metric_rules_section(comparison_result),
          compatibility_details(comparison_result),
          diagnostics_section(comparison_result),
          policy_rule_section(policy_result),
          reproduction_section(comparison_result),
          machine_readable_section(comparison_path),
          exit_code_section(policy_result)
        ].compact.join("\n\n")
      end

      def header(policy_result)
        "## Perfgate Performance Assurance\n\n" \
          "**Overall policy:** #{policy_result["status"].upcase}\n\n" \
          "**Evidence:** #{policy_result["evidence_status"].to_s.upcase}"
      end

      def identities(comparison_result)
        "- Baseline run: `#{comparison_result["baseline_run_id"]}`\n" \
          "- Candidate run: `#{comparison_result["candidate_run_id"]}`"
      end

      def workloads_table(comparison_result)
        workloads = comparison_result.fetch("workloads", [])
        return "_No workloads were compared._" if workloads.empty?

        ([table_header] + workloads.flat_map { |workload| workload_rows(workload) }).join("\n")
      end

      def table_header
        "| Workload | Metric | Baseline | Candidate | Change | Interval | Samples | Decision |\n" \
          "|---|---|---|---|---|---|---|---|"
      end

      def workload_rows(workload)
        return [summary_row(workload)] if workload["metrics"].empty?

        workload["metrics"].map { |name, metric| metric_row(workload["id"], name, metric) }
      end

      def summary_row(workload)
        "| #{workload["id"]} | - | - | - | - | - | - | #{workload["decision"].upcase} |"
      end

      def metric_row(workload_id, name, metric)
        noise = metric["noisy"] ? " ⚠️ noisy" : ""
        samples = "#{metric["baseline_sample_size"] || 0}/#{metric["candidate_sample_size"] || 0}"
        "| #{workload_id} | #{name} | #{format_value(name, metric["baseline_median"])} | " \
          "#{format_value(name, metric["candidate_median"])} | #{format_change(metric["change_percent"])} | " \
          "#{format_interval(metric)} | #{samples} | #{metric["decision"].upcase}#{noise} |"
      end

      def format_change(percent)
        percent ? format("%+.1f%%", percent) : "n/a"
      end

      def format_value(name, value)
        return "n/a" if value.nil?

        DURATION_METRICS.include?(name) ? format("%.2fms", value / 1_000_000.0) : value.to_s
      end

      def format_interval(metric)
        percent = metric.dig("interval", "percent")
        return "n/a" unless percent

        level = metric.dig("interval", "confidence_level")
        format("%.1f%% [%+.1f%%, %+.1f%%]", level.to_f * 100, percent["lower"], percent["upper"])
      end

      def compatibility_details(comparison_result)
        differences = comparison_result.dig("compatibility", "differences") || []
        return nil if differences.empty?

        "**Comparability reservations:**\n" + differences.map do |difference|
          "- `#{difference["field"]}`: #{difference["reason"] || "changed"} (#{difference["severity"]})"
        end.join("\n")
      end

      def metric_rules_section(comparison_result)
        rules = comparison_result.fetch("workloads", []).flat_map do |workload|
          workload.fetch("metrics", {}).filter_map do |name, metric|
            "- `#{workload["id"]}.#{name}`: #{metric["rule"]}" if metric["rule"]
          end
        end
        rules.empty? ? nil : "**Decision rules:**\n#{rules.join("\n")}"
      end

      def diagnostics_section(comparison_result)
        messages = diagnostic_messages(comparison_result)
        return nil if messages.empty?

        "**Diagnostics:**\n#{messages.map { |message| "- #{message}" }.join("\n")}"
      end

      def diagnostic_messages(comparison_result)
        workload_messages = comparison_result.fetch("workloads", []).flat_map { |w| w["diagnostics"] || [] }
        run_messages = comparison_result.fetch("diagnostics", []).map { |d| d["message"] }
        workload_messages + run_messages
      end

      def machine_readable_section(comparison_path)
        return nil unless comparison_path

        "Machine-readable result: `#{comparison_path}`"
      end

      def policy_rule_section(policy_result)
        policy_result["rule"] ? "**Policy rule:** #{policy_result["rule"]}" : nil
      end

      def reproduction_section(comparison_result)
        command = comparison_result["reproduction_command"]
        command ? "**Reproduce:** `#{command}`" : nil
      end

      def exit_code_section(policy_result)
        "Exit code `#{policy_result["exit_code"]}` (#{policy_result["status"]}). " \
          "See the exit-code table in the docs for what each status means for CI."
      end
    end
  end
end
