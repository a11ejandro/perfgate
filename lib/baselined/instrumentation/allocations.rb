# frozen_string_literal: true

module Baselined
  module Instrumentation
    # Ruby object allocation count during a `Baselined.measure` block
    # (spec section 13.4), using the allocation counter built into every
    # supported Ruby version.
    module Allocations
      module_function

      def start
        GC.stat(:total_allocated_objects)
      end

      def finish(started_at)
        { "allocations" => GC.stat(:total_allocated_objects) - started_at }
      end
    end
  end
end
