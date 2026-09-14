# frozen_string_literal: true

module Perfgate
  class Config
    # Validates a merged configuration hash against Schema::TREE and a
    # handful of range/type rules that matter for Milestone 1 (sample and
    # warmup counts). Raises Perfgate::ConfigurationError on any problem,
    # per spec section 11 ("unknown keys fail validation").
    module Validator
      MINIMUM_SAMPLES = 3
      REQUIRED_STRICT_FINGERPRINTS = %w[
        ruby_engine ruby_version rails_version baseline_version_major database_adapter
        database_version_major dataset_hash dependency_lock_hash schema_hash instrumentation_hash
      ].freeze

      module_function

      def call(hash)
        check_unknown_keys(hash, Schema::TREE, [])
        check_version(hash)
        check_execution(hash)
        check_metrics(hash)
        check_comparison(hash)
        check_policy(hash)
        check_fingerprint(hash)
        hash
      end

      def check_unknown_keys(hash, schema, path)
        hash.each_key do |key|
          check_known_key(key, schema, path)

          nested_schema = schema[key]
          next unless nested_schema.is_a?(Hash)

          value = hash[key]
          unless value.is_a?(Hash)
            raise Perfgate::ConfigurationError, "expected #{(path + [key]).join(".")} to be a mapping"
          end

          check_unknown_keys(value, nested_schema, path + [key])
        end
      end

      def check_known_key(key, schema, path)
        return if schema.key?(key)

        raise Perfgate::ConfigurationError, "unknown configuration key: #{(path + [key]).join(".")}"
      end

      def check_version(hash)
        return if hash[:version] == 1

        raise Perfgate::ConfigurationError, "unsupported configuration version: #{hash[:version].inspect} (expected 1)"
      end

      def check_execution(hash)
        samples = hash.dig(:execution, :samples)
        warmup = hash.dig(:execution, :warmup)

        if samples && (!samples.is_a?(Integer) || samples < MINIMUM_SAMPLES)
          raise Perfgate::ConfigurationError,
                "execution.samples must be an integer >= #{MINIMUM_SAMPLES}, got #{samples.inspect}"
        end

        order = hash.dig(:execution, :order)
        unless %w[defined random].include?(order)
          raise Perfgate::ConfigurationError, "execution.order must be defined or random, got #{order.inspect}"
        end

        isolation = hash.dig(:execution, :isolation)
        unless isolation == "process_per_workload"
          raise Perfgate::ConfigurationError,
                "execution.isolation currently supports only process_per_workload, got #{isolation.inspect}"
        end

        reference_design = hash.dig(:execution, :reference_design)
        unless reference_design == "historical_stored_baseline"
          raise Perfgate::ConfigurationError,
                "execution.reference_design currently supports only historical_stored_baseline"
        end


        seed = hash.dig(:execution, :seed)
        unless seed.is_a?(Integer)
          raise Perfgate::ConfigurationError, "execution.seed must be an integer, got #{seed.inspect}"
        end

        fail_fast = hash.dig(:execution, :fail_fast)
        unless [true, false].include?(fail_fast)
          raise Perfgate::ConfigurationError, "execution.fail_fast must be true or false, got #{fail_fast.inspect}"
        end

        return unless warmup && (!warmup.is_a?(Integer) || warmup.negative?)

        raise Perfgate::ConfigurationError, "execution.warmup must be a non-negative integer, got #{warmup.inspect}"
      end

      def check_metrics(hash)
        supported = %i[duration sql_count sql_duration allocations gc]
        enabled = hash.fetch(:metrics).select { |_metric, options| options[:enabled] }.keys
        unsupported = enabled - supported
        raise Perfgate::ConfigurationError, "enabled metrics are not implemented: #{unsupported.join(", ")}" if unsupported.any?
        raise Perfgate::ConfigurationError, "at least one implemented metric must be enabled" if enabled.empty?
      end

      def check_comparison(hash)
        minimum = hash.dig(:comparison, :minimum_samples)
        unless minimum.is_a?(Integer) && minimum >= MINIMUM_SAMPLES
          raise Perfgate::ConfigurationError, "comparison.minimum_samples must be an integer >= #{MINIMUM_SAMPLES}"
        end
        if hash.dig(:execution, :samples) < minimum
          raise Perfgate::ConfigurationError,
                "execution.samples must be >= comparison.minimum_samples"
        end

        confidence = hash.dig(:comparison, :confidence_level)
        unless confidence.is_a?(Numeric) && confidence > 0.5 && confidence < 1.0
          raise Perfgate::ConfigurationError, "comparison.confidence_level must be between 0.5 and 1.0"
        end

        method = hash.dig(:comparison, :multiple_comparison_method)
        unless method == "bonferroni"
          raise Perfgate::ConfigurationError, "comparison.multiple_comparison_method currently supports only bonferroni"
        end

        maximum_age = hash.dig(:comparison, :max_baseline_age_seconds)
        unless maximum_age.nil? || (maximum_age.is_a?(Numeric) && maximum_age.positive?)
          raise Perfgate::ConfigurationError, "comparison.max_baseline_age_seconds must be positive or null"
        end

        noise = hash.dig(:comparison, :noise_ratio_threshold)
        unless noise.is_a?(Numeric) && noise >= 0
          raise Perfgate::ConfigurationError, "comparison.noise_ratio_threshold must be non-negative"
        end

        check_thresholds(hash.dig(:comparison, :practical_thresholds))
      end

      def check_thresholds(thresholds)
        thresholds.each do |metric, values|
          values.each do |name, value|
            next if value.is_a?(Numeric) && value >= 0

            raise Perfgate::ConfigurationError,
                  "comparison.practical_thresholds.#{metric}.#{name} must be non-negative"
          end
          warning = values[:warning_percent]
          failure = values[:failure_percent]
          next unless warning && failure && warning > failure

          raise Perfgate::ConfigurationError,
                "comparison.practical_thresholds.#{metric} warning_percent must not exceed failure_percent"
        end
      end

      def check_policy(hash)
        policy = hash.fetch(:policy)
        unless %w[advisory blocking].include?(policy[:mode])
          raise Perfgate::ConfigurationError, "policy.mode must be advisory or blocking, got #{policy[:mode].inspect}"
        end

        %i[fail_on inconclusive incompatible missing_baseline new_workload removed_workload].each do |key|
          next if %w[warn fail].include?(policy[key])

          raise Perfgate::ConfigurationError, "policy.#{key} must be warn or fail, got #{policy[key].inspect}"
        end
      end

      def check_fingerprint(hash)
        strict = hash.dig(:fingerprint, :strict)
        informational = hash.dig(:fingerprint, :informational)
        unless strict.is_a?(Array) && informational.is_a?(Array)
          raise Perfgate::ConfigurationError, "fingerprint.strict and fingerprint.informational must be arrays"
        end

        missing = REQUIRED_STRICT_FINGERPRINTS - strict
        return if missing.empty?

        raise Perfgate::ConfigurationError,
              "fingerprint.strict cannot omit required provenance: #{missing.join(", ")}"
      end
    end
  end
end
