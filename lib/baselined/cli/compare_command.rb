# frozen_string_literal: true

require "optparse"
require_relative "../config"
require_relative "../comparison/engine"
require_relative "../policy/engine"
require_relative "../storage/filesystem"
require_relative "../report/console"
require_relative "../report/markdown"

module Baselined
  class CLI
    # Implements `baseline compare` (spec section 10.3): loads two
    # already-produced result bundles, runs them through the comparison
    # engine and policy engine, saves the comparison document, prints a
    # console (or Markdown, with --format markdown) report, and exits
    # with the CI exit code from spec section 17.
    class CompareCommand
      def initialize(argv)
        @argv = argv.dup
        @options = { config: "baselined.yml" }
      end

      def call
        parse_options!
        require_bundle_options!
        config = load_configuration

        comparison_result = compare(config)
        policy_result = Policy::Engine.evaluate(comparison_result: comparison_result, config: config)

        comparison_path = save(config, comparison_result)
        report(comparison_result, policy_result, comparison_path)
        policy_result.fetch("exit_code")
      end

      private

      def compare(config)
        baseline_run = load_bundle(@options[:baseline])
        candidate_run = load_bundle(@options[:candidate])

        Comparison::Engine.compare(baseline_run: baseline_run, candidate_run: candidate_run, config: config)
      end

      def require_bundle_options!
        return if @options[:baseline] && @options[:candidate]

        raise Baselined::ConfigurationError, "baseline compare requires both --baseline and --candidate"
      end

      def load_configuration
        config = Baselined::Config.load(@options[:config])
        Baselined.configuration = config
        config
      end

      def load_bundle(reference)
        Storage::Filesystem.new(root: File.dirname(reference)).load_run(reference)
      end

      def save(config, comparison_result)
        Storage::Filesystem.new(root: @options[:output] || config.storage_path).save_comparison(comparison_result)
      end

      def parse_options!
        option_parser.parse!(@argv)
      end

      def option_parser
        OptionParser.new do |opts|
          opts.on("--baseline PATH") { |v| @options[:baseline] = v }
          opts.on("--candidate PATH") { |v| @options[:candidate] = v }
          opts.on("--config PATH") { |v| @options[:config] = v }
          opts.on("--output PATH") { |v| @options[:output] = v }
          opts.on("--format FORMAT") { |v| @options[:format] = v }
        end
      end

      def report(comparison_result, policy_result, comparison_path)
        if @options[:format] == "markdown"
          puts Report::Markdown.render(comparison_result: comparison_result, policy_result: policy_result,
                                       comparison_path: comparison_path)
        else
          puts Report::Console.render(comparison_result: comparison_result, policy_result: policy_result)
          puts "Machine-readable result: #{comparison_path}"
        end
      end
    end
  end
end
