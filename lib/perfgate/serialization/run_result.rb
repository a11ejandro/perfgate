# frozen_string_literal: true

require "securerandom"
require "time"
require "shellwords"
require_relative "../statistics/summary"
require_relative "../fingerprints/components"

module Perfgate
  module Serialization
    # Builds the schema_version 2 run-result document described in spec
    # section 14.1. Fingerprinting and source/assurance metadata are
    # populated here so the comparison engine can
    # decide compatibility without re-deriving it from scratch.
    module RunResult
      SCHEMA_VERSION = 2

      module_function

      def build(workload_results, config: Perfgate.configuration)
        {
          "schema_version" => SCHEMA_VERSION,
          "run_id" => SecureRandom.uuid,
          "created_at" => Time.now.utc.iso8601,
          "fingerprint" => Fingerprints::Components.collect(config: config),
          "experiment_plan" => experiment_plan(config),
          "dataset" => config.dataset_spec,
          "analysis_configuration" => config.to_h.fetch(:comparison),
          "policy" => { "version" => 1, "configuration" => config.policy },
          "reproduction_command" => reproduction_command(config),
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
          "assurance" => result["assurance"] || {},
          "source" => result["source"] || {},
          "exclusions" => result["exclusions"] || [],
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
        samples.each_with_object([]) do |sample, keys|
          keys.concat(sample.keys.reject { |key| key.start_with?("_") })
        end.uniq
      end

      def experiment_plan(config)
        {
          "reference_design" => config.execution_reference_design,
          "samples" => config.execution_samples,
          "warmup" => config.execution_warmup,
          "seed" => config.execution_seed,
          "order" => config.execution_order,
          "isolation" => config.dig(:execution, :isolation),
          "metrics" => config.enabled_metrics.map(&:to_s)
        }
      end

      def reproduction_command(config)
        "bundle exec perfgate run --config perfgate.yml --seed #{config.execution_seed} " \
          "--profile #{Shellwords.escape(config.dig(:profile).to_s)}"
      end
    end
  end
end
