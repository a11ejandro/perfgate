# frozen_string_literal: true

require "json"
require "rbconfig"
require "tempfile"
require_relative "runner"

module Perfgate
  module Execution
    # Runs a workload's warmup + samples inside a fresh child process
    # (spec section 12.1: default "process_per_workload" isolation). The
    # child relays its result to the parent as JSON over a pipe -- Marshal
    # is deliberately avoided per the project's cross-process
    # serialization policy (data crossing a process boundary must not be
    # able to instantiate arbitrary Ruby objects).
    #
    # Note for database-backed workloads: an in-memory SQLite database
    # does not survive fork (each child effectively starts with an empty
    # database), so process isolation requires a file-based or
    # server-based test database. This mirrors an existing constraint on
    # Rails' own parallel test runners and isn't specific to Perfgate.
    class ProcessRunner
      def initialize(workload, runner_class: Runner, config_path: "perfgate.yml")
        @workload = workload
        @runner_class = runner_class
        @config_path = config_path
      end

      def call
        return spawn_clean_process if reloadable_workload?

        ensure_fork_supported!
        release_active_record_connections

        reader, writer = IO.pipe
        pid = fork_child(reader, writer)
        writer.close
        payload = reader.read
        reader.close
        _pid, status = Process.waitpid2(pid)

        parse_result(payload, status)
      end

      private

      def reloadable_workload?
        @runner_class == Runner && source_file && @workload.source["digest"]
      end

      def source_file
        @source_file ||= @workload.source["location"].to_s.sub(/:\d+\z/, "")
        @source_file unless @source_file.empty?
      end

      def spawn_clean_process
        Tempfile.create(["perfgate-result", ".json"]) do |result_file|
          Tempfile.create(["perfgate-child", ".log"]) do |log_file|
            result_path = result_file.path
            result_file.close
            pid = Process.spawn(*subprocess_command(result_path), out: log_file.path, err: [:child, :out])
            _pid, status = Process.waitpid2(pid)
            payload = File.exist?(result_path) ? File.read(result_path) : ""
            parse_result(payload, status, child_log: File.read(log_file.path))
          end
        end
      end

      def subprocess_command(result_path)
        library_path = File.expand_path("../..", __dir__)
        expression = "status = Perfgate::Execution::SubprocessEntry.call(ARGV); exit!(status)"
        [RbConfig.ruby, "-I#{library_path}", "-rperfgate/execution/subprocess_entry", "-e", expression,
         @config_path, source_file, @workload.id, result_path]
      end

      def ensure_fork_supported!
        return if Process.respond_to?(:fork)

        raise Perfgate::Error, "process isolation requires Process.fork, which this Ruby platform does not support"
      end

      def release_active_record_connections
        return unless defined?(::ActiveRecord::Base)

        handler = ::ActiveRecord::Base.connection_handler
        return handler.clear_all_connections! if handler.respond_to?(:clear_all_connections!)

        handler.clear_active_connections!
      end

      def fork_child(reader, writer)
        Process.fork do
          reader.close
          result = @runner_class.new(@workload).call
          writer.write(JSON.generate(result))
          writer.close
          exit!(0)
        end
      end

      def parse_result(payload, status, child_log: nil)
        if payload.nil? || payload.empty?
          process_status = status.exitstatus || "signal #{status.termsig}"
          detail = child_log.to_s.strip
          detail = detail[-2_000, 2_000] if detail.length > 2_000
          {
            "id" => @workload.id,
            "status" => "error",
            "samples" => [],
            "error" => "workload process exited without a result (#{process_status})#{detail.empty? ? "" : ": #{detail}"}"
          }
        else
          JSON.parse(payload)
        end
      end
    end
  end
end
