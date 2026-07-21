# frozen_string_literal: true

module Baseline
  # Entry point for the `baseline` executable. Subcommands (init, run,
  # compare, report, doctor, schema) will be implemented as part of the
  # Milestone 1 build-out described in the project roadmap.
  class CLI
    def self.start(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
    end

    def run
      warn "baseline: no subcommands implemented yet"
      1
    end
  end
end
