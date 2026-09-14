# frozen_string_literal: true

module Perfgate
  class Config
    # Declares which keys perfgate.yml recognizes at each nesting level.
    # A Hash value means "this key has its own nested keys"; `true` marks
    # a leaf value. Used to enforce "unknown keys fail validation" from
    # spec section 11.
    module Schema
      TREE = {
        version: true,
        profile: true,
        execution: {
          samples: true,
          warmup: true,
          seed: true,
          order: true,
          fail_fast: true,
          isolation: true,
          reference_design: true
        },
        dataset: {
          id: true,
          schema_version: true,
          generator_version: true,
          seed: true,
          scale: true,
          cardinality: true,
          skew: true,
          null_rates: true,
          relationships: true,
          cache_state: true
        },
        metrics: {
          duration: { enabled: true },
          sql_count: { enabled: true },
          sql_duration: { enabled: true },
          allocations: { enabled: true },
          gc: { enabled: true },
          memory: { enabled: true }
        },
        comparison: {
          minimum_samples: true,
          confidence_level: true,
          multiple_comparison_method: true,
          max_baseline_age_seconds: true,
          noise_ratio_threshold: true,
          practical_thresholds: {
            duration: { warning_percent: true, failure_percent: true, minimum_absolute_ms: true },
            sql_count: { warning_absolute: true, failure_percent: true },
            sql_duration: { warning_percent: true, failure_percent: true, minimum_absolute_ms: true },
            allocations: { warning_percent: true, failure_percent: true }
          }
        },
        policy: {
          mode: true,
          fail_on: true,
          inconclusive: true,
          incompatible: true,
          missing_baseline: true,
          new_workload: true,
          removed_workload: true
        },
        fingerprint: { strict: true, informational: true },
        storage: { adapter: true, path: true },
        telemetry: { enabled: true }
      }.freeze
    end
  end
end
