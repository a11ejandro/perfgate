# frozen_string_literal: true

require_relative "sample_context"
require_relative "../fingerprints/workload_definition"
require "time"

module Perfgate
  module Execution
    # Executes a single workload's warmup and measured samples in the
    # current process (spec section 12.2, steps 4-9). Process isolation
    # across workloads is layered on top by ProcessRunner. SQL count/
    # duration, allocations, and GC deltas are collected only inside the
    # workload's explicit `Perfgate.measure` block; duration falls back
    # to wall-clock timing of the whole workload when `Perfgate.measure`
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
        samples = []
        @active_observation = nil
        @workload.warmup.times { |index| run_once(sequence: index, phase: "warmup") }

        @workload.samples.times { |index| samples << run_once(sequence: index, phase: "measurement") }

        result("completed", samples, nil, [])
      rescue StandardError => e
        error = "#{e.class}: #{e.message}"
        exclusions = @active_observation ? [@active_observation.merge("status" => "error", "error" => error)] : []
        result("error", samples || [], error, exclusions)
      end

      private

      def result(status, samples, error, exclusions)
        {
          "id" => @workload.id, "status" => status, "samples" => samples, "error" => error,
          "definition_hash" => Fingerprints::WorkloadDefinition.hash_for(@workload),
          "assurance" => @workload.assurance,
          "source" => @workload.source,
          "exclusions" => exclusions
        }
      end

      def run_once(sequence: 0, phase: "measurement")
        data = nil
        started_at = Time.now.utc.iso8601(6)
        monotonic_started_ns = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
        @active_observation = {
          "sequence" => sequence, "phase" => phase, "started_at" => started_at,
          "monotonic_started_ns" => monotonic_started_ns
        }

        SampleContext.with_new(metrics: @workload.metrics) do |context|
          wall_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          @workload.call
          wall_elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall_start

          data = context.data.dup
          if @workload.metrics.map(&:to_sym).include?(:duration)
            data["duration_ns"] ||= (wall_elapsed * 1_000_000_000).round
          end
          data["_meta"] = {
            "sequence" => sequence,
            "phase" => phase,
            "started_at" => started_at,
            "monotonic_started_ns" => monotonic_started_ns,
            "status" => "completed"
          }
        end

        @active_observation = nil
        data
      end
    end
  end
end
