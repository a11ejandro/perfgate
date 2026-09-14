# frozen_string_literal: true

require "digest"
require "json"

module Perfgate
  module Fingerprints
    # Computes a per-workload definition hash from the properties that,
    # if changed, would make a historical run incomparable to a new one
    # (spec section 15.4): the workload's id, its sample/warmup counts,
    # the set of metrics it records, the assurance contract, and the
    # source-file digest. The raw digest is intentionally conservative:
    # even formatting-only edits require a fresh comparable reference.
    module WorkloadDefinition
      module_function

      def hash_for(workload)
        payload = {
          "id" => workload.id,
          "samples" => workload.samples,
          "warmup" => workload.warmup,
          "metrics" => Array(workload.metrics).map(&:to_s).sort,
          "assurance" => workload.assurance.reject { |key, _value| key == "owner" },
          "source_digest" => workload.source["digest"]
        }
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(payload))}"
      end
    end
  end
end
