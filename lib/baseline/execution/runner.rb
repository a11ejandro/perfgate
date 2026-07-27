# frozen_string_literal: true

require_relative "sample_context"

module Baseline
  module Execution
    # Executes a single workload's warmup and measured samples in the
    # current process (spec section 12.2, steps 4-9). Process isolation
    # across workloads is layered on top by ProcessRunner. SQL count/
    # duration, allocations, and GC deltas are collected only inside the
    # workload's explicit `Baseline.measure` block; duration falls back
    # to wall-clock timing of the whole workload when `Baseline.measure`
    # is never called (spec section 13.1).
    #
    # A failed assertion or raised exception inside the workload is an
    # execution error, not a performance regression (spec section 12.2):
    # it aborts this workload's run and is reported as `status: "error"`
    # rather than raising out of `call`.
    class Runner
      def initialize(workload)
        @workload = workload
      end

      def call
        @workload.warmup.times { run_once }

        samples = Array.new(@workload.samples) { run_once }

        { "id" => @workload.id, "status" => "completed", "samples" => samples, "error" => nil }
      rescue StandardError => e
        { "id" => @workload.id, "status" => "error", "samples" => [], "error" => "#{e.class}: #{e.message}" }
      end

      private

      def run_once
        data = nil

        SampleContext.with_new(metrics: @workload.metrics) do |context|
          wall_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @workload.call
          wall_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall_start

          data = context.data.dup
          data["duration_ns"] ||= (wall_elapsed * 1_000_000_000).round
        end

        data
      end
    end
  end
end
