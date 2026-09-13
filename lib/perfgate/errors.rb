# frozen_string_literal: true

module Perfgate
  # Base class for all Perfgate-raised errors.
  class Error < StandardError; end

  # Raised when perfgate.yml is missing, malformed, or fails schema validation.
  class ConfigurationError < Error; end

  # Raised when a workload cannot be executed as configured (e.g. missing
  # RSpec example, invalid metadata, duplicate workload id).
  class WorkloadError < Error; end

  # Raised when a candidate and baseline run cannot be safely compared.
  class IncompatibleRunError < Error; end

  # Raised when a result bundle is malformed, tampered with, or fails
  # checksum verification.
  class ResultBundleError < Error; end
end
