# frozen_string_literal: true

require "securerandom"
require "time"
require_relative "../statistics/summary"
require_relative "../fingerprints/components"

module Baseline
  module Serialization
    # Builds the schema_version 1 run-result document described in spec
    # section 14.1. Milestone 5 will add source metadata; fingerprinting
    # (spec section 15) is populated here so the comparison engine can
    # decide compatibility without re-deriving it from scratch.
    module RunResult
      SCHEMA_VERSION = 1

      module_function

      def build(workload_results, config: Baseline.configuration)
        {
          "schema_version" => SCHEMA_VERSION,
          "run_id" => SecureRandom.uuid,
          "created_at" => Time.now.utc.iso8601,
          "fingerprint" => Fingerprints::Components.collect(config: config),
          "workloads" => workload_results.map { |result| build_workload(result) }
        }
      end

      def build_workload(result)
        samples = result.fetch("samples")

        {
          "id" => result.fetch("id"),
          "status" => result.fetch("status"),
          "error" => result["error"],
          "definition_hash" => result["definition_hash"],
          "samples" => samples,
          "summary" => summarize(samples)
        }
      end

      # Every metric key present in at least one sample gets its own
      # summary block (spec section 14.1 shows this for duration_ns, but
      # the same shape applies to sql_count, sql_duration_ns, etc. once
      # those metrics are enabled).
      def summarize(samples)
        metric_keys(samples).each_with_object({}) do |key, summary|
          values = samples.map { |sample| sample[key] }.compact
          summary[key] = Statistics::Summary.call(values)
        end
      end

      def metric_keys(samples)
        samples.each_with_object([]) { |sample, keys| keys.concat(sample.keys) }.uniq
      end
    end
  end
end
