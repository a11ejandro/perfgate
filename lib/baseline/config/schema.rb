# frozen_string_literal: true

module Baseline
  class Config
    # Declares which keys baseline.yml recognizes at each nesting level.
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
          isolation: true
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
          noise_ratio_threshold: true,
          practical_thresholds: {
            duration: { warning_percent: true, failure_percent: true, minimum_absolute_ms: true },
            sql_count: { warning_absolute: true, failure_percent: true },
            sql_duration: { warning_percent: true, failure_percent: true, minimum_absolute_ms: true },
            allocations: { warning_percent: true, failure_percent: true }
          }
        },
        policy: {
          fail_on: true,
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
