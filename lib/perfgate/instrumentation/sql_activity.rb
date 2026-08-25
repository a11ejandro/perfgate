# frozen_string_literal: true

module Perfgate
  module Instrumentation
    # SQL query count and cumulative duration during a `Perfgate.measure`
    # block (spec sections 13.2-13.3), collected via an
    # ActiveSupport::Notifications subscription scoped to exactly that
    # block. Schema queries, transaction control statements, and cached
    # query hits are excluded as configurable noise (13.2); raw SQL text
    # is never stored, only counts and a cumulative duration.
    module SqlActivity
      NOISE_EVENT_NAMES = %w[SCHEMA TRANSACTION].freeze

      module_function

      def start
        ensure_active_support!

        state = { count: 0, duration_ns: 0 }
        subscriber = ::ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
          event = ::ActiveSupport::Notifications::Event.new(*args)
          record(state, event) unless noise?(event.payload)
        end
        { subscriber: subscriber, state: state }
      end

      def finish(started)
        ::ActiveSupport::Notifications.unsubscribe(started.fetch(:subscriber))
        state = started.fetch(:state)
        { "sql_count" => state[:count], "sql_duration_ns" => state[:duration_ns] }
      end

      def record(state, event)
        state[:count] += 1
        state[:duration_ns] += (event.duration * 1_000_000).round
      end

      def noise?(payload)
        NOISE_EVENT_NAMES.include?(payload[:name].to_s) || payload[:cached]
      end

      def ensure_active_support!
        return if defined?(::ActiveSupport::Notifications)

        raise Perfgate::Error,
              "sql_count/sql_duration instrumentation requires ActiveSupport::Notifications to be loaded"
      end
    end
  end
end
