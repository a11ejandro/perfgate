# frozen_string_literal: true

module Baseline
  module Instrumentation
    # Wall-clock duration of a `Baseline.measure` block (spec section
    # 13.1). Uses a monotonic clock so NTP adjustments and system clock
    # changes never produce a negative or inflated reading.
    module Duration
      module_function

      def start
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def finish(started_at)
        { "duration_ns" => ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1_000_000_000).round }
      end
    end
  end
end
