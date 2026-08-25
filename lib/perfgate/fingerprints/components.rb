# frozen_string_literal: true

require "digest"
require "etc"

module Perfgate
  module Fingerprints
    # Collects the run-level fingerprint component values referenced by
    # the strict/informational field lists in config.fingerprint (spec
    # section 15.1/15.2). `workload_definition_hash` is deliberately
    # excluded here: it is computed per-workload
    # (see WorkloadDefinition) and compared per-workload in the
    # comparison engine, not as a run-wide component.
    module Components
      module_function

      def collect(config: Perfgate.configuration)
        strict_components(config).merge(informational_components)
      end

      def strict_components(config)
        {
          "ruby_engine" => RUBY_ENGINE,
          "ruby_version" => RUBY_VERSION,
          "rails_version" => rails_version,
          "baseline_version_major" => Perfgate::VERSION.split(".").first,
          "database_adapter" => database_adapter,
          "database_version_major" => database_version_major,
          "dataset_hash" => dataset_hash(config)
        }
      end

      def informational_components
        {
          "operating_system" => operating_system,
          "cpu_model" => cpu_model,
          "cpu_count" => Etc.nprocessors.to_s,
          "memory_bytes" => nil,
          "ci_provider" => ci_provider,
          "runner_image" => ENV.fetch("PERFGATE_RUNNER_IMAGE", nil),
          "dependency_lock_hash" => dependency_lock_hash
        }
      end

      def rails_version
        defined?(::Rails) ? ::Rails.version : nil
      end

      def database_adapter
        return nil unless defined?(::ActiveRecord::Base)

        ::ActiveRecord::Base.connection.adapter_name
      rescue StandardError
        nil
      end

      def database_version_major
        return nil unless defined?(::ActiveRecord::Base)

        version = ::ActiveRecord::Base.connection.database_version
        version.to_s.split(".").first
      rescue StandardError, NotImplementedError
        nil
      end

      # Applications provide their own dataset fingerprint hook (spec
      # section 12.3, e.g. a fixture set version or seed migration
      # number); Baseline only ever stores its hash, never the raw value,
      # to avoid leaking application data into shared run artifacts.
      def dataset_hash(config)
        raw = config.dataset_fingerprint.call
        "sha256:#{Digest::SHA256.hexdigest(raw.to_s)}"
      end

      def operating_system
        RbConfig::CONFIG["host_os"]
      end

      def cpu_model
        ENV.fetch("PERFGATE_CPU_MODEL", nil)
      end

      def ci_provider
        return "github_actions" if ENV["GITHUB_ACTIONS"]
        return "gitlab_ci" if ENV["GITLAB_CI"]
        return "circleci" if ENV["CIRCLECI"]

        nil
      end

      # Deferred: hashing Gemfile.lock (or equivalent) is a small addition
      # but out of Milestone 3's explicit scope; left nil until wired up.
      def dependency_lock_hash
        nil
      end
    end
  end
end
