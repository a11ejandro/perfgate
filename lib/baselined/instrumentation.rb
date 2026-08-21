# frozen_string_literal: true

require_relative "instrumentation/duration"
require_relative "instrumentation/sql_activity"
require_relative "instrumentation/allocations"
require_relative "instrumentation/gc"

module Baselined
  # Instrumentation collectors for the metrics a workload can measure
  # (spec section 13): each collector module exposes `.start`/`.finish`
  # and is invoked only within a workload's explicit `Baselined.measure`
  # block.
  module Instrumentation
    # Maps a workload's configured metric names (spec section 11's
    # `metrics` config, e.g. `:duration`, `:sql_count`) to the collector
    # module responsible for it. `sql_count` and `sql_duration` share a
    # single collector since both come from the same notification
    # subscription. `memory` (section 13.6) is intentionally absent: it
    # is disabled by default and not yet implemented.
    REGISTRY = {
      duration: Duration,
      sql_count: SqlActivity,
      sql_duration: SqlActivity,
      allocations: Allocations,
      gc: Gc
    }.freeze

    module_function

    # The distinct set of collectors needed to satisfy the given metric
    # names, in a stable order.
    def collectors_for(metric_names)
      metric_names.filter_map { |name| REGISTRY[name] }.uniq
    end
  end
end
