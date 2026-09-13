# frozen_string_literal: true

require 'json'
require 'time'

module Letsdo
  class SessionRecorder
    # Writes the optional JSON Lines metrics stream for a session recorder:
    # a session_start line on construction, one run_finished line per closed
    # run and a session_stop line at the end. With a nil IO the writer is a
    # no-op, so callers need no nil checks.
    class JsonlWriter
      # @param io [IO, nil] append-only target; nil disables the writer
      # @param name [String] agent name
      # @param handle [String] assignee handle
      # @param wall_clock [Proc] -> ISO8601 UTC timestamp string
      def initialize(io, name:, handle:, wall_clock:)
        @io = io
        @name = name
        @handle = handle
        @wall_clock = wall_clock
        session_start if enabled?
      end

      # @return [Boolean] whether an output target is configured
      def enabled?
        !@io.nil?
      end

      # Writes the opening session_start line (no-op when disabled).
      #
      # @return [void]
      def session_start
        write(session_start_payload)
      end

      # @param run [SessionRecorder::Run] a closed run record
      # @return [void]
      def run_finished(run)
        write(
          'event' => 'run_finished', 'task' => run.task_id, 'exit' => run.exit_code,
          'outcome' => run.outcome.to_s, 'elapsed_s' => run.elapsed_s,
          'ts' => @wall_clock.call
        )
      end

      # @param summary [SessionRecorder::Summary] the final aggregate
      # @return [void]
      def session_stop(summary)
        write(
          'event' => 'session_stop', 'agent' => @name, 'handle' => @handle,
          'ts' => @wall_clock.call, 'done' => summary.done, 'failed' => summary.failed,
          'interrupted' => summary.interrupted, 'left' => summary.left,
          'session_s' => summary.session_s, 'runs_s' => summary.active_s
        )
      end

      private

      def session_start_payload
        { 'event' => 'session_start', 'agent' => @name, 'handle' => @handle,
          'ts' => @wall_clock.call }
      end

      def write(payload)
        return unless enabled?

        @io.puts(JSON.generate(payload))
        @io.flush if @io.respond_to?(:flush)
      end
    end
  end
end
