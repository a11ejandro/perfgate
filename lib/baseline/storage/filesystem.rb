# frozen_string_literal: true

require "digest"
require "fileutils"
require "json"
require_relative "adapter"

module Baseline
  module Storage
    # Default MVP storage adapter (spec section 18.2). Layout:
    #
    #   <root>/runs/<run-id>/manifest.json
    #   <root>/runs/<run-id>/run.json
    #   <root>/runs/<run-id>/checksums.json
    #
    # `save_comparison` and filtering in `list_runs` are deferred: the
    # comparison engine isn't implemented until a later milestone.
    class Filesystem < Adapter
      def initialize(root:)
        super()
        @root = root
      end

      def save_run(run_result)
        run_id = run_result.fetch("run_id")
        dir = run_directory(run_id)
        FileUtils.mkdir_p(dir)

        run_json = JSON.pretty_generate(run_result)
        File.write(File.join(dir, "run.json"), run_json)
        File.write(File.join(dir, "manifest.json"), JSON.pretty_generate(manifest_for(run_result)))
        File.write(File.join(dir, "checksums.json"), JSON.pretty_generate(checksums_for(run_json)))

        dir
      end

      def load_run(reference)
        dir = File.directory?(reference) ? reference : run_directory(reference)
        run_json_path = File.join(dir, "run.json")

        raise Baseline::ResultBundleError, "no run result found at #{run_json_path}" unless File.exist?(run_json_path)

        verify_checksum!(dir, run_json_path)
        JSON.parse(File.read(run_json_path))
      end

      def list_runs(filters = {}) # rubocop:disable Lint/UnusedMethodArgument
        base = File.join(@root, "runs")
        return [] unless File.directory?(base)

        Dir.children(base).sort
      end

      def save_comparison(comparison_result)
        raise NotImplementedError, "comparison storage is not implemented yet"
      end

      private

      def run_directory(run_id)
        File.join(@root, "runs", run_id)
      end

      def manifest_for(run_result)
        {
          "schema_version" => run_result["schema_version"],
          "run_id" => run_result["run_id"],
          "created_at" => run_result["created_at"],
          "workload_ids" => run_result.fetch("workloads").map { |w| w["id"] }
        }
      end

      def checksums_for(run_json)
        { "run.json" => "sha256:#{Digest::SHA256.hexdigest(run_json)}" }
      end

      def verify_checksum!(dir, run_json_path)
        checksums_path = File.join(dir, "checksums.json")
        return unless File.exist?(checksums_path)

        expected = JSON.parse(File.read(checksums_path))["run.json"]
        return unless expected

        actual = "sha256:#{Digest::SHA256.hexdigest(File.read(run_json_path))}"
        return if actual == expected

        raise Baseline::ResultBundleError, "checksum mismatch for #{run_json_path}"
      end
    end
  end
end
