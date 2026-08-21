# frozen_string_literal: true

module Baselined
  # Entry point for the `baseline` executable. `run` and `compare` are
  # implemented (Milestones 1-4); `init`, `report`, `doctor`, and
  # `schema` are planned for later milestones (spec section 10).
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      dispatch(*@argv)
    rescue Baselined::ConfigurationError => e
      warn "baseline: #{e.message}"
      2
    rescue Baselined::ResultBundleError, Baselined::WorkloadError => e
      warn "baseline: #{e.message}"
      3
    rescue Baselined::Error => e
      warn "baseline: #{e.message}"
      1
    end

    private

    def dispatch(command = nil, *rest)
      case command
      when "run" then run_run_command(rest)
      when "compare" then run_compare_command(rest)
      when nil then usage
      else unknown_command(command)
      end
    end

    def run_run_command(rest)
      require_relative "cli/run_command"
      RunCommand.new(rest).call
    end

    def run_compare_command(rest)
      require_relative "cli/compare_command"
      CompareCommand.new(rest).call
    end

    def usage
      warn "usage: baseline <command> [options]"
      1
    end

    def unknown_command(command)
      warn "baseline: unknown or not-yet-implemented command #{command.inspect}"
      1
    end
  end
end
