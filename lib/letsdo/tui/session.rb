# frozen_string_literal: true

require_relative 'session/keys'
require_relative 'session/view'

module Letsdo
  module Tui
    # The TUI controller: terminal lifecycle, background input thread, and
    # the repaint loop around an orchestrator run.
    class Session
      include SessionKeys
      include SessionView

      REPAINT_INTERVAL = 1.0
      IDLE_SLEEP = 0.01
      INPUT_JOIN_TIMEOUT = 2.0

      def initialize(**opts)
        assign_identity(opts)
        assign_io(opts)
        assign_controls(opts)
        reset_view_state
      end

      def run(&work)
        install_winch_handler
        @terminal.enter
        result = run_work(&work)
        raise_input_error!
        result
      rescue Letsdo::Stopped
        raise_input_error!
        0
      ensure
        restore_terminal
      end

      def run_work(&work)
        with_raw_input do
          start_input_thread
          work.call
        end
      end

      # Re-raises a failure captured by the background input/render thread
      # so a paint or input error is never silently swallowed into a blank,
      # unresponsive TUI (TASK-92). Called after the work ends, on both the
      # normal and the stopped path, before the ensure restores the terminal;
      # the error therefore propagates only once the alternate screen is left.
      #
      # A fresh instance is raised rather than the captured object: quit
      # interrupts the main thread from inside the input thread's rescue, so
      # the injected Letsdo::Stopped already carries the captured error as its
      # cause, and re-raising that object would form a circular cause chain.
      def raise_input_error!
        return unless @input_error

        error = @input_error
        raise error.class, error.message, error.backtrace
      end

      private

      def assign_identity(opts)
        @name = opts.fetch(:name)
        @handle = opts.fetch(:handle)
        @log = opts.fetch(:log)
        @metrics = opts.fetch(:metrics)
      end

      def assign_io(opts)
        @terminal = opts.fetch(:terminal)
        @input = opts.fetch(:input)
        @refresh = opts[:refresh]
        @wait_seconds = opts.fetch(:wait_seconds, 10.0)
        @clock = opts[:clock] || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      end

      def assign_controls(opts)
        @pause_gate = opts[:pause_gate]
        @runner = opts[:runner]
      end

      def reset_view_state
        @offset = 0
        @follow = true
        @paused = false
        @stop = false
        @winch = false
        @body_height = 1
        @seen_version = 0
        @input_thread = nil
        @input_error = nil
      end

      # Enters raw mode on the keyboard for the duration of the block. Held
      # by the main thread (not the killable input thread) so the terminal
      # state is restored on every quit path — a killed input thread would
      # leave the shared tty in raw mode and break the calling shell (TASK-83).
      def with_raw_input(&block)
        if @input.stdin.tty? && @input.stdin.respond_to?(:raw)
          @input.stdin.raw(&block)
        else
          block.call
        end
      end

      def install_winch_handler
        Signal.trap('SIGWINCH') { @winch = true }
      rescue ArgumentError
        nil
      end

      def restore_winch_handler
        Signal.trap('SIGWINCH', 'DEFAULT')
      rescue ArgumentError
        nil
      end

      def start_input_thread
        @input_thread = Thread.new { input_loop }
        @input_thread.report_on_exception = false
        @input_thread
      end

      def stop_input_thread
        @stop = true
        thread = @input_thread
        return unless thread

        thread.join(INPUT_JOIN_TIMEOUT) || thread.kill
      end

      # Runs the full terminal cleanup on every exit path: stops the input
      # thread, leaves the alternate screen and restores the SIGWINCH handler.
      def restore_terminal
        stop_input_thread
        leave_terminal
        restore_winch_handler
      end

      def leave_terminal
        @terminal.leave
      end
    end
  end
end
