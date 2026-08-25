# frozen_string_literal: true

module Perfgate
  class Config
    # Applies PERFGATE_-prefixed environment variable overrides on top of
    # a merged configuration hash, per spec section 11 ("environment-
    # variable overrides use a documented PERFGATE_ prefix"). Any leaf
    # path can be overridden, e.g. PERFGATE_EXECUTION_SAMPLES=12 overrides
    # execution.samples. The override is type-coerced based on the
    # existing default value at that path.
    module EnvOverrides
      PREFIX = "PERFGATE_"

      module_function

      def apply(hash, env: ENV)
        each_leaf_path(hash) do |path, current_value|
          env_key = PREFIX + path.join("_").upcase
          next unless env.key?(env_key)

          set_path(hash, path, coerce(env[env_key], current_value))
        end
        hash
      end

      def each_leaf_path(hash, prefix = [], &block)
        hash.each do |key, value|
          path = prefix + [key]
          if value.is_a?(Hash)
            each_leaf_path(value, path, &block)
          else
            block.call(path, value)
          end
        end
      end

      def set_path(hash, path, value)
        *init, last = path
        target = init.reduce(hash) { |h, k| h[k] }
        target[last] = value
      end

      def coerce(raw, current_value)
        case current_value
        when Integer then Integer(raw)
        when Float then Float(raw)
        when true, false then %w[1 true yes on].include?(raw.downcase)
        when Array then raw.split(",").map(&:strip)
        else raw
        end
      end
    end
  end
end
