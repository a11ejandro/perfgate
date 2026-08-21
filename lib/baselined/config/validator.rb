# frozen_string_literal: true

module Baselined
  class Config
    # Validates a merged configuration hash against Schema::TREE and a
    # handful of range/type rules that matter for Milestone 1 (sample and
    # warmup counts). Raises Baselined::ConfigurationError on any problem,
    # per spec section 11 ("unknown keys fail validation").
    module Validator
      MINIMUM_SAMPLES = 3

      module_function

      def call(hash)
        check_unknown_keys(hash, Schema::TREE, [])
        check_version(hash)
        check_execution(hash)
        hash
      end

      def check_unknown_keys(hash, schema, path)
        hash.each_key do |key|
          check_known_key(key, schema, path)

          nested_schema = schema[key]
          next unless nested_schema.is_a?(Hash)

          value = hash[key]
          unless value.is_a?(Hash)
            raise Baselined::ConfigurationError, "expected #{(path + [key]).join(".")} to be a mapping"
          end

          check_unknown_keys(value, nested_schema, path + [key])
        end
      end

      def check_known_key(key, schema, path)
        return if schema.key?(key)

        raise Baselined::ConfigurationError, "unknown configuration key: #{(path + [key]).join(".")}"
      end

      def check_version(hash)
        return if hash[:version] == 1

        raise Baselined::ConfigurationError, "unsupported configuration version: #{hash[:version].inspect} (expected 1)"
      end

      def check_execution(hash)
        samples = hash.dig(:execution, :samples)
        warmup = hash.dig(:execution, :warmup)

        if samples && (!samples.is_a?(Integer) || samples < MINIMUM_SAMPLES)
          raise Baselined::ConfigurationError,
                "execution.samples must be an integer >= #{MINIMUM_SAMPLES}, got #{samples.inspect}"
        end

        return unless warmup && (!warmup.is_a?(Integer) || warmup.negative?)

        raise Baselined::ConfigurationError, "execution.warmup must be a non-negative integer, got #{warmup.inspect}"
      end
    end
  end
end
