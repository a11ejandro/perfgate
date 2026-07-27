# frozen_string_literal: true

module Baseline
  module Instrumentation
    # Garbage-collection activity during a `Baseline.measure` block (spec
    # section 13.5). `gc_count` matches the run-result schema in section
    # 14.1; `gc_minor_count`/`gc_major_count` are additional diagnostic
    # deltas the schema doesn't name explicitly but section 13.5 asks us
    # to capture. GC metrics are diagnostic only and never fail a run.
    module Gc
      module_function

      def start
        {
          count: GC.stat(:count),
          minor_count: GC.stat(:minor_gc_count),
          major_count: GC.stat(:major_gc_count)
        }
      end

      def finish(started_at)
        {
          "gc_count" => GC.stat(:count) - started_at[:count],
          "gc_minor_count" => GC.stat(:minor_gc_count) - started_at[:minor_count],
          "gc_major_count" => GC.stat(:major_gc_count) - started_at[:major_count]
        }
      end
    end
  end
end
