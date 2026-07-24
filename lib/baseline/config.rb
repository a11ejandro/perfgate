# frozen_string_literal: true

require "yaml"
require_relative "config/defaults"
require_relative "config/schema"
require_relative "config/validator"
require_relative "config/env_overrides"

module Baseline
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
      def load(path = "baseline.yml")
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
        raise Baseline::ConfigurationError, "invalid YAML in #{path}: #{e.message}"
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

    attr_reader :to_h

    def initialize(hash)
      @to_h = hash
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

    def dig(*keys)
      to_h.dig(*keys)
    end
  end
end
