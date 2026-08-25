# frozen_string_literal: true

require "pathname"

module Perfgate
  module RSpec
    # Computes the stable workload identifier for an RSpec example, per
    # spec section 9.2: "<spec file relative path>:<RSpec example full
    # description>", unless overridden via `perfgate: { id: "..." }`.
    module IdResolver
      module_function

      def resolve(example)
        explicit_id(example) || "#{relative_spec_path(example)}:#{example.full_description}"
      end

      def explicit_id(example)
        metadata = example.metadata[:perfgate]
        return nil unless metadata.is_a?(Hash)

        metadata[:id]
      end

      def relative_spec_path(example)
        absolute = File.expand_path(example.metadata[:file_path])
        Pathname.new(absolute).relative_path_from(Pathname.pwd).to_s
      end
    end
  end
end
