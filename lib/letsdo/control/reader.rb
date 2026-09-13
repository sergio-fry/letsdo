# frozen_string_literal: true

module Letsdo
  module Control
    # The plain-mode control reader (TASK-94): when letsdo runs in plain
    # line-stream mode (stdout not a TTY) but stdin IS a terminal, a
    # background thread reads Enter-terminated commands and maps them to
    # the same actions as the TUI keys (TASK-67/74 control model):
    #
    #   p - toggle pause: on -> Control::PauseGate#pause plus the running
    #       backend's SIGSTOP (a no-op when nothing runs), off -> resume;
    #   q - clean stop: Thread.main.raise(Letsdo::Stopped), the exact
    #       teardown path of SIGINT/SIGTERM and the TUI 'q'.
    #
    # The reader only starts for a terminal stdin: with a pipe or
    # /dev/null it never reads a single byte, so a user's piped stdin is
    # left untouched and stopping stays signal-only. It writes nothing
    # (no echo, no escape codes, no partial output) and its thread exits
    # quietly on EOF or a read error.
    class Reader
      # @param input [IO] the stdin stream to read lines from
      # @param pause_gate [Letsdo::Control::PauseGate, nil] the between-runs
      #        gate toggled by 'p'
      # @param runner [#call, nil] callable returning the current backend
      #        (answers pause/resume) or nil; mirrors the TUI wiring, so a
      #        nil between runs is simply a no-op
      # @param on_stop [#call, nil] stop action; defaults to raising
      #        Letsdo::Stopped into the main thread (injected in tests)
      # @param tty [Boolean, nil] overrides the input.tty? check (tests only)
      def initialize(input:, pause_gate: nil, runner: nil, on_stop: nil, tty: nil)
        @input = input
        @pause_gate = pause_gate
        @runner = runner
        @on_stop = on_stop
        @tty = tty
        @paused = false
        @thread = nil
      end

      # Whether the reader may run: stdin must be a terminal that can be
      # read line by line, otherwise a pipe, /dev/null or CI stdin would be
      # read from (and stolen from the user's pipe).
      #
      # @return [Boolean]
      def available?
        @tty.nil? ? terminal_input? : @tty
      end

      # Starts the background reader thread. A non-terminal stdin starts
      # nothing at all.
      #
      # @return [Thread, nil] the reader thread, or nil when not a terminal
      def start
        return nil unless available?
        return @thread if @thread

        @thread = build_thread
      end

      # Waits for the reader thread so tests and shutdown can join it.
      #
      # @param timeout [Numeric, nil] seconds to wait, nil waits forever
      # @return [Thread, nil]
      def join(timeout = nil)
        @thread&.join(timeout)
      end

      # Ends the reader: kills the background thread when it is still
      # blocked on input, so no reader outlives the run that started it.
      # Safe to call when it was never started (non-TTY stdin).
      #
      # @return [void]
      def stop
        thread = @thread
        return unless thread

        thread.kill
        thread.join(1)
        @thread = nil
      end

      private

      def terminal_input?
        @input.respond_to?(:tty?) && @input.tty? && @input.respond_to?(:gets)
      end

      def build_thread
        Thread.new { read_loop }.tap { |thread| thread.report_on_exception = false }
      end

      # Reads Enter-terminated commands until EOF or a read error; never
      # writes and never lets an error escape the thread.
      def read_loop
        while (line = @input.gets)
          handle_command(line)
        end
      rescue IOError, SystemCallError
        nil
      end

      def handle_command(line)
        case line.strip
        when 'p' then toggle_pause
        when 'q' then request_stop
        end
      end

      def toggle_pause
        @paused = !@paused
        action = @paused ? :pause : :resume
        invoke(@pause_gate, action)
        invoke(current_runner, action)
      end

      def current_runner
        @runner.respond_to?(:call) ? @runner.call : @runner
      end

      def invoke(target, action)
        return unless target.respond_to?(action)

        target.public_send(action)
      end

      def request_stop
        (@on_stop || -> { Thread.main.raise(Letsdo::Stopped) }).call
      end
    end
  end
end
