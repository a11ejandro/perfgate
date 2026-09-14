# frozen_string_literal: true

require "optparse"
require_relative "../config"
require_relative "../execution/process_runner"
require_relative "../serialization/run_result"
require_relative "../storage/filesystem"
require_relative "run_comparison_reporter"

module Perfgate
  class CLI
    # Implements `perfgate run` (spec section 10.2): discovers workloads
    # via the RSpec integration, executes each workload's warmup+samples
    # in an isolated child process, and writes a filesystem result
    # bundle. With --compare PATH, immediately compares the fresh run
    # against a reference bundle and reports/exits like `perfgate
    # compare` would -- this is the single combined step the spec's
    # GitHub Actions example (section 19.1) invokes. --format markdown
    # additionally writes a summary.md into the output directory for a
    # GitHub job summary.
    class RunCommand
      def initialize(argv)
        @argv = argv.dup
        @options = { config: "perfgate.yml" }
      end

      def call
        parse_options!
        config = load_configuration
        run_result = execute(config)
        run_dir = save(config, run_result)

        @options[:compare] ? compare_and_report(config, run_result) : run_only_report(config, run_result, run_dir)
      end

      private

      def load_configuration
        config = Perfgate::Config.load(@options[:config])
        apply_cli_overrides(config)
        Perfgate::Config::Validator.call(config.to_h)
        Perfgate.configuration = config
        config
      end

      def apply_cli_overrides(config)
        config.to_h[:execution][:seed] = @options[:seed] if @options.key?(:seed)
        config.to_h[:profile] = @options[:profile] if @options[:profile]
        config.to_h[:policy][:fail_on] = @options[:fail_on] if @options[:fail_on]
      end

      def execute(config)
        require "perfgate/rspec"
        load_spec_files
        Perfgate::RSpec::Discovery.call

        workloads = selected_workloads(config)
        results = execute_workloads(workloads, config)
        Serialization::RunResult.build(results, config: config)
      end

      def selected_workloads(config)
        workloads = Perfgate.registry.to_a
        workloads.select! { |workload| File.fnmatch?(@options[:only], workload.id) } if @options[:only]
        workloads.shuffle!(random: Random.new(config.execution_seed)) if config.execution_order == "random"
        workloads
      end

      def execute_workloads(workloads, config)
        results = []
        workloads.each do |workload|
          result = Execution::ProcessRunner.new(workload, config_path: @options[:config]).call
          results << result
          break if config.execution_fail_fast && result["status"] == "error"
        end
        results
      end

      def save(config, run_result)
        Storage::Filesystem.new(root: @options[:output] || config.storage_path).save_run(run_result)
      end

      def parse_options!
        option_parser.parse!(@argv)
      end

      def option_parser # rubocop:disable Metrics/AbcSize
        OptionParser.new do |opts|
          opts.on("--config PATH") { |v| @options[:config] = v }
          opts.on("--output PATH") { |v| @options[:output] = v }
          opts.on("--only PATTERN") { |v| @options[:only] = v }
          opts.on("--format FORMAT") { |v| @options[:format] = v }
          opts.on("--fail-on MODE") { |v| @options[:fail_on] = v }
          opts.on("--seed N", Integer) { |v| @options[:seed] = v }
          opts.on("--profile NAME") { |v| @options[:profile] = v }
          opts.on("--compare PATH") { |v| @options[:compare] = v }
        end
      end

      def load_spec_files
        options = ::RSpec::Core::ConfigurationOptions.new(spec_paths)
        options.configure(::RSpec.configuration)
        ::RSpec.configuration.load_spec_files
      end

      def spec_paths
        @argv.empty? ? ["spec"] : @argv
      end

      def run_only_report(config, run_result, run_dir)
        puts "perfgate run: #{run_result["workloads"].size} workload(s) -> #{run_dir}"
        run_result["workloads"].each { |workload| report_workload(workload) }
        write_run_only_summary(run_result, output_root(config))
        exit_code(run_result)
      end

      def report_workload(workload)
        summary = workload.dig("summary", "duration_ns")
        if workload["status"] == "completed" && summary
          median_ms = summary["median"] / 1_000_000.0
          puts format("  %<id>-40s median=%<median>.2fms (n=%<count>d)",
                      id: workload["id"], median: median_ms, count: workload["samples"].size)
        else
          puts "  #{workload["id"]}: #{workload["status"]} (#{workload["error"]})"
        end
      end

      def exit_code(run_result)
        run_result["workloads"].any? { |w| w["status"] == "error" } ? 3 : 0
      end

      def write_run_only_summary(run_result, run_dir)
        return unless @options[:format] == "markdown"

        rows = run_result["workloads"].map { |w| "| #{w["id"]} | #{w["status"]} |" }
        content = (["## Perfgate Run", "", "No reference bundle was compared against.", "",
                    "| Workload | Status |", "|---|---|"] + rows).join("\n")
        File.write(File.join(run_dir, "summary.md"), content)
      end

      def compare_and_report(config, run_result)
        reporter = RunComparisonReporter.new(reference_path: @options[:compare],
                                             output_root: output_root(config),
                                             format: @options[:format])
        reporter.call(config: config, run_result: run_result, run_dir: output_root(config))
      end

      def output_root(config)
        @options[:output] || config.storage_path
      end
    end
  end
end
