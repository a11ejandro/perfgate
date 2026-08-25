# frozen_string_literal: true

module Perfgate
  module Storage
    # Interface every storage backend implements (spec section 18.1).
    class Adapter
      def save_run(run_result)
        raise NotImplementedError, "#{self.class} must implement #save_run"
      end

      def load_run(reference)
        raise NotImplementedError, "#{self.class} must implement #load_run"
      end

      def list_runs(filters = {})
        raise NotImplementedError, "#{self.class} must implement #list_runs"
      end

      def save_comparison(comparison_result)
        raise NotImplementedError, "#{self.class} must implement #save_comparison"
      end
    end
  end
end
