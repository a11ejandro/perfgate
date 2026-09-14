# frozen_string_literal: true

require "json"
require "rspec/core"
require_relative "../../perfgate"
require_relative "../rspec"
require_relative "runner"

module Perfgate
  module Execution
    # Reloads one RSpec-backed workload in a clean Ruby process. This avoids
    # inheriting native database/client state from a loaded Rails parent,
    # which is not safe to use after fork on every platform.
    module SubprocessEntry
      module_function

      def call(argv)
        config_path, source_file, workload_id, result_path = argv
        config = Perfgate::Config.load(config_path)
        Perfgate.configuration = config
        load_spec(source_file)
        Perfgate::RSpec::Discovery.call
        workload = Perfgate.registry[workload_id]
        raise Perfgate::WorkloadError, "workload not found in child process: #{workload_id.inspect}" unless workload

        write_result(result_path, Runner.new(workload).call)
        0
      rescue StandardError => e
        write_result(result_path, error_result(workload_id, e)) if result_path
        1
      end

      def load_spec(source_file)
        options = ::RSpec::Core::ConfigurationOptions.new([source_file])
        options.configure(::RSpec.configuration)
        ::RSpec.configuration.load_spec_files
      end

      def write_result(path, result)
        File.write(path, JSON.generate(result))
      end

      def error_result(workload_id, error)
        {
          "id" => workload_id,
          "status" => "error",
          "samples" => [],
          "error" => "#{error.class}: #{error.message}",
          "exclusions" => []
        }
      end
    end
  end
end
