# frozen_string_literal: true

require_relative 'control/reader'

module Letsdo
  # Agent-control primitives shared by the TUI, the plain-mode reader and
  # the orchestrator loop (TASK-67 control model): pausing between runs
  # (PauseGate) and the stdin control reader (Reader).
  module Control
    # A thread-safe pause flag polled by Letsdo::AgentLoop between runs.
    #
    # Mid-run suspension is handled by Letsdo::Backends::Pi#pause (SIGSTOP to
    # the pi group, kernel-level freeze). Between runs there is no pi to
    # stop, so the pause lives in this gate: while #paused? is true the
    # loop must not start a new run, and it waits until #resume.
    #
    # The flag is toggled from the TUI input thread ('p' key) and polled
    # from the loop's main thread (AgentLoop#wrapped_run), so every access
    # is mutex-guarded.
    class PauseGate
      def initialize
        @mutex = Mutex.new
        @paused = false
      end

      # Sets the paused state (a no-op when already paused).
      def pause
        @mutex.synchronize { @paused = true }
      end

      # Clears the paused state (a no-op when not paused).
      def resume
        @mutex.synchronize { @paused = false }
      end

      # @return [Boolean] whether the gate is paused
      def paused?
        @mutex.synchronize { @paused }
      end
    end
  end
end
