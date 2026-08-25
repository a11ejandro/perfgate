# frozen_string_literal: true

require_relative "../comparison/engine"
require_relative "../policy/engine"
require_relative "../report/console"
require_relative "../report/markdown"
require_relative "../storage/filesystem"

module Perfgate
  class CLI
    # Handles `baseline run`'s optional --compare PATH step: loads the
    # reference bundle (tolerating a missing one, since the spec's
    # GitHub Actions example downloads it with continue-on-error),
    # compares it against the freshly-run result, saves and reports the
    # comparison, and returns the CI exit code. Split out of RunCommand
    # to keep both classes under RuboCop's length limits.
    class RunComparisonReporter
      def initialize(reference_path:, output_root:, format:)
        @reference_path = reference_path
        @output_root = output_root
        @format = format
      end

      def call(config:, run_result:, run_dir:)
        reference_run = load_reference
        return missing_baseline_report(config, run_dir) unless reference_run

        comparison_result = Comparison::Engine.compare(baseline_run: reference_run, candidate_run: run_result,
                                                       config: config)
        report_comparison(config, comparison_result, run_dir)
      end

      private

      def load_reference
        Storage::Filesystem.new(root: File.dirname(@reference_path)).load_run(@reference_path)
      rescue Perfgate::ResultBundleError
        nil
      end

      def missing_baseline_report(config, run_dir)
        policy_result = Policy::Engine.evaluate_missing_baseline(config: config)
        puts "baseline run: no baseline found at #{@reference_path} -> #{policy_result["status"]}"
        write_summary(run_dir, "## Baseline Run\n\nNo baseline was found at `#{@reference_path}`.") if markdown?
        policy_result.fetch("exit_code")
      end

      def report_comparison(config, comparison_result, run_dir)
        policy_result = Policy::Engine.evaluate(comparison_result: comparison_result, config: config)
        comparison_path = Storage::Filesystem.new(root: @output_root).save_comparison(comparison_result)

        render(comparison_result, policy_result, comparison_path, run_dir)
        policy_result.fetch("exit_code")
      end

      def render(comparison_result, policy_result, comparison_path, run_dir)
        markdown = Report::Markdown.render(comparison_result: comparison_result, policy_result: policy_result,
                                           comparison_path: comparison_path)
        if markdown?
          puts markdown
          write_summary(run_dir, markdown)
        else
          puts Report::Console.render(comparison_result: comparison_result, policy_result: policy_result)
          puts "Machine-readable result: #{comparison_path}"
        end
      end

      def markdown?
        @format == "markdown"
      end

      def write_summary(run_dir, content)
        File.write(File.join(run_dir, "summary.md"), content)
      end
    end
  end
end
