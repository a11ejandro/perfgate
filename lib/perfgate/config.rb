# frozen_string_literal: true

require "yaml"
require_relative "config/defaults"
require_relative "config/schema"
require_relative "config/validator"
require_relative "config/env_overrides"

module Perfgate
  # Loads, validates, and provides typed access to baseline.yml (spec
  # section 11). Configuration is a plain merged Hash under the hood;
  # this class only adds convenience readers for the values Milestone 1
  # actually acts on (execution sample/warmup counts, enabled metrics,
  # storage path). Later milestones will add readers for comparison,
  # policy, and fingerprint sections as those are implemented.
  class Config
    class << self
      # A Config built entirely from defaults, with no file on disk.
      def default
        new(deep_dup(Defaults::HASH))
      end

      # Loads baseline.yml (or the given path). A missing file is treated
      # as an empty configuration, i.e. pure defaults.
      def load(path = "perfgate.yml")
        raw = read_yaml(path)
        merged = deep_merge(deep_dup(Defaults::HASH), raw)
        EnvOverrides.apply(merged)
        Validator.call(merged)
        new(merged)
      end

      private

      def read_yaml(path)
        return {} unless File.exist?(path)

        content = YAML.safe_load_file(path, permitted_classes: [Symbol], symbolize_names: true)
        content || {}
      rescue Psych::SyntaxError => e
        raise Perfgate::ConfigurationError, "invalid YAML in #{path}: #{e.message}"
      end

      # A small recursive dup that avoids Marshal (forbidden project-wide
      # for serialization) while still deep-copying nested hashes/arrays
      # so mutating a loaded Config never mutates the frozen defaults.
      def deep_dup(value)
        case value
        when Hash
          value.each_with_object({}) { |(k, v), acc| acc[k] = deep_dup(v) }
        when Array
          value.map { |v| deep_dup(v) }
        else
          value
        end
      end

      def deep_merge(base, override)
        base.merge(override) do |_key, base_val, override_val|
          if base_val.is_a?(Hash) && override_val.is_a?(Hash)
            deep_merge(base_val, override_val)
          else
            override_val
          end
        end
      end
    end

    # The default dataset fingerprint hook (spec section 12.3): apps that
    # care about dataset drift affecting comparability can override this
    # with a callable of their own via `Perfgate.configure`.
    DEFAULT_DATASET_FINGERPRINT = -> { ENV.fetch("PERFGATE_DATASET_VERSION", "unspecified") }

    attr_reader :to_h
    attr_accessor :dataset_fingerprint

    def initialize(hash)
      @to_h = hash
      @dataset_fingerprint = DEFAULT_DATASET_FINGERPRINT
    end

    def execution_samples
      to_h.dig(:execution, :samples)
    end

    def execution_warmup
      to_h.dig(:execution, :warmup)
    end

    def enabled_metrics
      to_h.fetch(:metrics).select { |_name, opts| opts[:enabled] }.keys
    end

    # Defaults handed to newly-discovered workloads that don't override
    # samples/warmup/metrics themselves (spec section 9.3).
    def execution_defaults
      { samples: execution_samples, warmup: execution_warmup, metrics: enabled_metrics }
    end

    def storage_path
      to_h.dig(:storage, :path)
    end

    def comparison_minimum_samples
      to_h.dig(:comparison, :minimum_samples)
    end

    def comparison_confidence_level
      to_h.dig(:comparison, :confidence_level)
    end

    def comparison_noise_ratio_threshold
      to_h.dig(:comparison, :noise_ratio_threshold)
    end

    def practical_thresholds
      to_h.dig(:comparison, :practical_thresholds)
    end

    def fingerprint_strict_fields
      to_h.dig(:fingerprint, :strict)
    end

    def fingerprint_informational_fields
      to_h.dig(:fingerprint, :informational)
    end

    def policy
      to_h.fetch(:policy)
    end

    def dig(*keys)
      to_h.dig(*keys)
    end
  end
end
