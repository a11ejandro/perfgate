# frozen_string_literal: true

module Perfgate
  module Workloads
    # Collects Workload instances discovered for a run and enforces the
    # uniqueness rule from spec section 9.2: "a duplicate explicit ID is
    # a configuration error".
    class Registry
      include Enumerable

      class << self
        def instance
          @instance ||= new
        end

        def reset!
          @instance = new
        end
      end

      def initialize
        @workloads = {}
      end

      def register(workload)
        raise Perfgate::WorkloadError, "duplicate workload id: #{workload.id.inspect}" if @workloads.key?(workload.id)

        @workloads[workload.id] = workload
      end

      def [](id)
        @workloads[id]
      end

      def each(&block)
        return enum_for(:each) unless block

        @workloads.each_value(&block)
      end

      def ids
        @workloads.keys
      end

      def clear
        @workloads.clear
      end
    end
  end
end
