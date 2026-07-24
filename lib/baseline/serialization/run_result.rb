# frozen_string_literal: true

require "securerandom"
require "time"
require_relative "../statistics/summary"

module Baseline
  module Serialization
    # Builds the schema_version 1 run-result document described in spec
    # section 14.1. Milestone 1 only populates the duration metric;
    # SQL/allocation/GC fields are added in Milestone 2, and
    # fingerprint/source metadata are added in Milestone 5.
    module RunResult
      SCHEMA_VERSION = 1

      module_function

      def build(workload_results)
        {
          "schema_version" => SCHEMA_VERSION,
          "run_id" => SecureRandom.uuid,
          "created_at" => Time.now.utc.iso8601,
          "workloads" => workload_results.map { |result| build_workload(result) }
        }
      end

      def build_workload(result)
        samples = result.fetch("samples")
        durations = samples.map { |sample| sample.fetch("duration_ns") }

        {
          "id" => result.fetch("id"),
          "status" => result.fetch("status"),
          "error" => result["error"],
          "samples" => samples,
          "summary" => durations.empty? ? {} : { "duration_ns" => Statistics::Summary.call(durations) }
        }
      end
    end
  end
end
