# frozen_string_literal: true

require "json"
require_relative "runner"

module Baseline
  module Execution
    # Runs a workload's warmup + samples inside a fresh child process
    # (spec section 12.1: default "process_per_workload" isolation). The
    # child relays its result to the parent as JSON over a pipe -- Marshal
    # is deliberately avoided per the project's cross-process
    # serialization policy (data crossing a process boundary must not be
    # able to instantiate arbitrary Ruby objects).
    class ProcessRunner
      def initialize(workload, runner_class: Runner)
        @workload = workload
        @runner_class = runner_class
      end

      def call
        ensure_fork_supported!

        reader, writer = IO.pipe
        pid = fork_child(reader, writer)
        writer.close
        payload = reader.read
        reader.close
        _pid, status = Process.waitpid2(pid)

        parse_result(payload, status)
      end

      private

      def ensure_fork_supported!
        return if Process.respond_to?(:fork)

        raise Baseline::Error, "process isolation requires Process.fork, which this Ruby platform does not support"
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

      def parse_result(payload, status)
        if payload.nil? || payload.empty?
          {
            "id" => @workload.id,
            "status" => "error",
            "samples" => [],
            "error" => "workload process exited without a result (exit status #{status.exitstatus})"
          }
        else
          JSON.parse(payload)
        end
      end
    end
  end
end
