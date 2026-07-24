# frozen_string_literal: true

require "optparse"
require_relative "../config"
require_relative "../execution/process_runner"
require_relative "../serialization/run_result"
require_relative "../storage/filesystem"

module Baseline
  class CLI
    # Implements `baseline run` (spec section 10.2): discovers workloads
    # via the RSpec integration, executes each workload's warmup+samples
    # in an isolated child process, and writes a filesystem result
    # bundle. Comparing against a previous bundle (--compare) belongs to
    # a later milestone; only local execution + serialization exists so
    # far.
    class RunCommand
      def initialize(argv)
        @argv = argv.dup
        @options = { config: "baseline.yml" }
      end

      def call
        parse_options!
        config = load_configuration
        run_result = execute(config)
        run_dir = save(config, run_result)

        report(run_result, run_dir)
        exit_code(run_result)
      end

      private

      def load_configuration
        config = Baseline::Config.load(@options[:config])
        Baseline.configuration = config
        config
      end

      def execute(_config)
        require "baseline/rspec"
        load_spec_files
        Baseline::RSpec::Discovery.call

        results = Baseline.registry.map { |workload| Execution::ProcessRunner.new(workload).call }
        Serialization::RunResult.build(results)
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

      def report(run_result, run_dir)
        puts "baseline run: #{run_result["workloads"].size} workload(s) -> #{run_dir}"
        run_result["workloads"].each { |workload| report_workload(workload) }
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
        run_result["workloads"].any? { |w| w["status"] == "error" } ? 1 : 0
      end
    end
  end
end
