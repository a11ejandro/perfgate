# frozen_string_literal: true

require "digest"
require "etc"
require "json"
require "open3"
require "socket"

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
          "dataset_hash" => dataset_hash(config),
          "dependency_lock_hash" => dependency_lock_hash,
          "schema_hash" => schema_hash,
          "instrumentation_hash" => instrumentation_hash(config)
        }
      end

      def informational_components
        {
          "operating_system" => operating_system,
          "kernel_release" => kernel_release,
          "cpu_model" => cpu_model,
          "cpu_count" => Etc.nprocessors.to_s,
          "memory_bytes" => memory_bytes,
          "ci_provider" => ci_provider,
          "runner_image" => ENV["PERFGATE_RUNNER_IMAGE"] || ENV["ImageOS"] || "unmanaged",
          "executor_identity" => executor_identity,
          "source_revision" => source_revision,
          "source_dirty" => source_dirty
        }
      end

      def rails_version
        defined?(::Rails) ? ::Rails.version : nil
      end

      def database_adapter
        return nil unless defined?(::ActiveRecord::Base)

        ::ActiveRecord::Base.connection.adapter_name
      rescue StandardError
        "local"
      end

      def database_version_major
        return nil unless defined?(::ActiveRecord::Base)

        connection = ::ActiveRecord::Base.connection
        version = connection.database_version
        if connection.adapter_name.to_s.downcase.include?("postgres") && version.is_a?(Integer)
          return (version / 10_000).to_s
        end

        version.to_s.split(".").first
      rescue StandardError, NotImplementedError
        nil
      end

      # Applications provide their own dataset fingerprint hook (spec
      # section 12.3, e.g. a fixture set version or seed migration
      # number); Perfgate only ever stores its hash, never the raw value,
      # to avoid leaking application data into shared run artifacts.
      def dataset_hash(config)
        specification = config.dataset_spec.reject { |_key, value| value.nil? }
        raw = specification.empty? ? config.dataset_fingerprint.call : JSON.generate(specification.sort.to_h)
        return nil if raw.nil? || raw.to_s.empty?

        "sha256:#{Digest::SHA256.hexdigest(raw.to_s)}"
      end

      def operating_system
        RbConfig::CONFIG["host_os"]
      end

      def cpu_model
        return ENV["PERFGATE_CPU_MODEL"] if ENV["PERFGATE_CPU_MODEL"]
        return File.read("/proc/cpuinfo")[/^model name\s*:\s*(.+)$/, 1] if File.file?("/proc/cpuinfo")

        capture("sysctl", "-n", "machdep.cpu.brand_string")
      end

      def kernel_release
        Etc.uname[:release]
      rescue StandardError
        nil
      end

      def memory_bytes
        if File.file?("/proc/meminfo")
          kilobytes = File.read("/proc/meminfo")[/^MemTotal:\s+(\d+)\s+kB$/, 1]
          return kilobytes.to_i * 1024 if kilobytes
        end

        value = capture("sysctl", "-n", "hw.memsize")
        value&.match?(/\A\d+\z/) ? value.to_i : nil
      end

      def ci_provider
        return "github_actions" if ENV["GITHUB_ACTIONS"]
        return "gitlab_ci" if ENV["GITLAB_CI"]
        return "circleci" if ENV["CIRCLECI"]

        "local"
      end

      def dependency_lock_hash
        digest_first_existing(ENV["PERFGATE_LOCKFILE"], "Gemfile.lock")
      end

      def schema_hash
        digest_first_existing(ENV["PERFGATE_SCHEMA_FILE"], "db/schema.rb", "db/structure.sql")
      end

      def instrumentation_hash(config)
        payload = JSON.generate(config.enabled_metrics.map(&:to_s).sort)
        "sha256:#{Digest::SHA256.hexdigest(payload)}"
      end

      def source_revision
        ENV["GITHUB_SHA"] || capture("git", "rev-parse", "HEAD")
      end

      def source_dirty
        output = capture("git", "status", "--porcelain")
        output.nil? ? nil : !output.empty?
      end

      def executor_identity
        ENV["RUNNER_NAME"] || ENV["CI_RUNNER_ID"] || Socket.gethostname
      rescue StandardError
        nil
      end

      def digest_first_existing(*paths)
        path = paths.compact.find { |candidate| File.file?(candidate) }
        path ? "sha256:#{Digest::SHA256.file(path).hexdigest}" : nil
      end

      def capture(*command)
        output, status = Open3.capture2e(*command)
        status.success? ? output.strip : nil
      rescue Errno::ENOENT
        nil
      end
    end
  end
end
