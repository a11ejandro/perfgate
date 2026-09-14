# frozen_string_literal: true

require "perfgate"

module MethodologyFixtures
  def methodology_fingerprint(overrides = {})
    {
      "ruby_engine" => "ruby", "ruby_version" => "3.2.2", "rails_version" => "7.1.0",
      "baseline_version_major" => "0", "database_adapter" => "SQLite", "database_version_major" => "3",
      "dataset_hash" => "sha256:dataset", "dependency_lock_hash" => "sha256:lock",
      "schema_hash" => "sha256:schema", "instrumentation_hash" => "sha256:instrumentation",
      "operating_system" => "darwin23", "cpu_model" => "Apple M2", "cpu_count" => "8",
      "memory_bytes" => "17179869184", "kernel_release" => "23.0.0", "ci_provider" => "github_actions",
      "runner_image" => "ubuntu-22.04", "executor_identity" => "fixture-runner"
    }.merge(overrides)
  end

  def methodology_assurance
    {
      "claim" => "Detect a material deterioration in the declared workload.",
      "owner" => "performance@example.test",
      "dataset" => { "id" => "fixture", "schema_version" => "1", "seed" => 12_345, "scale" => "small" },
      "metric_directions" => { "duration" => "lower_is_better", "sql_count" => "lower_is_better" },
      "minimum_effects" => {
        "duration" => { "warning_percent" => 10, "failure_percent" => 20, "minimum_absolute_ms" => 10 },
        "sql_count" => { "warning_absolute" => 1, "failure_percent" => 20 }
      }
    }
  end

  def methodology_experiment_plan
    { "reference_design" => "historical_stored_baseline", "samples" => 8, "warmup" => 2,
      "seed" => 12_345, "order" => "defined", "isolation" => "process_per_workload",
      "metrics" => %w[duration sql_count sql_duration allocations gc] }
  end


  def methodology_source
    { "location" => "spec/fixtures/performance_spec.rb:1", "digest" => "sha256:source" }
  end
end

RSpec.configure do |config|
  config.include MethodologyFixtures
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
