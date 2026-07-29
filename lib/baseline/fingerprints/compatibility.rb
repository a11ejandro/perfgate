# frozen_string_literal: true

module Baseline
  module Fingerprints
    # Decides whether a baseline run and a candidate run are comparable
    # at all, before any statistics are computed (spec section 15.3).
    # A difference in any "strict" field makes the runs incompatible;
    # a difference in an "informational" field only downgrades the
    # result to "compatible_with_warnings" (still comparable, but the
    # decision should be presented to the reader with that context).
    module Compatibility
      module_function

      def evaluate(baseline_components:, candidate_components:, config: Baseline.configuration)
        strict = diff_fields(baseline_components, candidate_components, config.fingerprint_strict_fields, "strict")
        informational = diff_fields(baseline_components, candidate_components,
                                    config.fingerprint_informational_fields, "informational")
        differences = strict + informational

        { "status" => status_for(differences), "differences" => differences }
      end

      def diff_fields(baseline_components, candidate_components, fields, severity)
        Array(fields).filter_map do |field|
          next if field == "workload_definition_hash"

          baseline_value = baseline_components[field]
          candidate_value = candidate_components[field]
          next if baseline_value == candidate_value

          { "field" => field, "severity" => severity, "baseline" => baseline_value, "candidate" => candidate_value }
        end
      end

      def status_for(differences)
        if differences.any? { |d| d["severity"] == "strict" }
          "incompatible"
        elsif differences.any?
          "compatible_with_warnings"
        else
          "compatible"
        end
      end
    end
  end
end
