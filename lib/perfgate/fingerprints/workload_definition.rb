# frozen_string_literal: true

require "digest"
require "json"

module Perfgate
  module Fingerprints
    # Computes a per-workload definition hash from the properties that,
    # if changed, would make a historical run incomparable to a new one
    # (spec section 15.4): the workload's id, its sample/warmup counts,
    # and the set of metrics it records. Hashing the workload's source
    # code (to detect behavioral changes even when these properties are
    # unchanged) is explicitly deferred -- the spec notes this requires
    # normalizing formatting/whitespace-only diffs, which is a larger
    # follow-up.
    module WorkloadDefinition
      module_function

      def hash_for(workload)
        payload = {
          "id" => workload.id,
          "samples" => workload.samples,
          "warmup" => workload.warmup,
          "metrics" => Array(workload.metrics).map(&:to_s).sort
        }
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(payload))}"
      end
    end
  end
end
