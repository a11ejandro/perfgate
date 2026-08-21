# frozen_string_literal: true

module Baselined
  class Config
    # Default configuration values, matching the illustrative baseline.yml
    # in spec section 11. `storage.path` intentionally uses the base
    # directory from section 18.2's layout (`.baseline`) rather than the
    # `.baseline/results` shown in section 11's example, since the two
    # sections of the spec disagree and 18.2 is the more specific
    # authority on directory layout.
    module Defaults
      HASH = {
        version: 1,
        profile: "default",
        execution: {
          samples: 8,
          warmup: 2,
          seed: 12_345,
          order: "defined",
          fail_fast: false,
          isolation: "process_per_workload"
        },
        metrics: {
          duration: { enabled: true },
          sql_count: { enabled: true },
          sql_duration: { enabled: true },
          allocations: { enabled: true },
          gc: { enabled: true },
          memory: { enabled: false }
        },
        comparison: {
          minimum_samples: 5,
          confidence_level: 0.95,
          # How much of a metric's own noise (MAD relative to its median)
          # we tolerate before treating a would-be "fail" as unreliable
          # and downgrading it to "warn" instead (spec 16.5). The spec
          # calls for noise-aware downgrading but doesn't name a default
          # ratio, so 0.5 (MAD up to half the median) was chosen as a
          # conservative starting point pending real-world tuning.
          noise_ratio_threshold: 0.5,
          practical_thresholds: {
            duration: { warning_percent: 10, failure_percent: 20, minimum_absolute_ms: 10 },
            sql_count: { warning_absolute: 1, failure_percent: 20 },
            sql_duration: { warning_percent: 15, failure_percent: 30, minimum_absolute_ms: 5 },
            allocations: { warning_percent: 15, failure_percent: 30 }
          }
        },
        policy: {
          fail_on: "fail",
          incompatible: "warn",
          missing_baseline: "warn",
          new_workload: "warn",
          removed_workload: "warn"
        },
        fingerprint: {
          strict: %w[
            ruby_engine ruby_version rails_version baseline_version_major
            database_adapter database_version_major workload_definition_hash dataset_hash
          ],
          informational: %w[
            operating_system cpu_model cpu_count memory_bytes
            ci_provider runner_image dependency_lock_hash
          ]
        },
        storage: { adapter: "filesystem", path: ".baselined" },
        telemetry: { enabled: false }
      }.freeze
    end
  end
end
