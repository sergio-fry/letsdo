# frozen_string_literal: true

module Letsdo
  module Tui
    # The metrics facade for the TUI header, fed by the loop driver.
    #
    # Data sources (TASK-38 architecture survey):
    #   done            - number of completed agent runs in this session,
    #                     counted from the loop's run_finished events;
    #   left            - latest open-task count from the backlog provider
    #                     (the loop reports it per iteration; 'r' forces an
    #                     immediate re-query);
    #   current task    - the task the agent is running now, started by
    #                     run_started and elapsed on a monotonic clock;
    #   session timer   - monotonic time since this facade was created;
    #   identity        - agent name and assignee handle (the header's
    #                     "name (@handle)" line).
    #
    # All state changes happen on the loop thread; snapshots are read by
    # the TUI input thread while the loop runs — hence the mutex. The
    # facade is deliberately generic: Letsdo::Loop stays untouched, the
    # events come from Letsdo::AgentLoop (wrapped_provider/wrapped_run).
    #
    # An optional on_run_start hook lets the caller (CLI) mark run
    # boundaries in the log when a run starts.
    class Metrics
      # An immutable snapshot of the header metrics at some moment.
      Snapshot = Struct.new(:name, :handle, :done, :left, :session_seconds,
                            :current_task, :current_task_seconds, keyword_init: true)

      # @param name [String] agent name (CLI argument)
      # @param handle [String] assignee handle (e.g. "@developer")
      # @param clock [Proc] monotonic clock, callable → seconds; injected
      #        in tests
      # @param on_run_start [Proc, nil] called with the task label when a
      #        run starts (the CLI uses it to insert a log divider)
      def initialize(name:, handle:, clock: nil, on_run_start: nil)
        @name = name
        @handle = handle
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        @on_run_start = on_run_start
        @mutex = Mutex.new
        @done = 0
        @left = nil
        @current_task = nil
        @current_started = nil
        @session_started = @clock.call
      end

      # An agent run started for a task: records the task label and the
      # monotonic run start time.
      #
      # @param task [String] task label
      def run_started(task)
        @on_run_start&.call(task)
        @mutex.synchronize do
          @current_task = task
          @current_started = @clock.call
        end
      end

      # An agent run finished: increments the done counter and clears the
      # current-task state.
      def run_finished
        @mutex.synchronize do
          @done += 1
          @current_task = nil
          @current_started = nil
        end
      end

      # The latest open-task count from the backlog provider.
      #
      # @param count [Integer, nil] number of open tasks; nil = the backlog
      #        state is unreadable
      def provider_result(count)
        @mutex.synchronize { @left = count }
      end

      # A point-in-time snapshot of all header metrics.
      #
      # @return [Snapshot]
      def snapshot
        now = @clock.call
        @mutex.synchronize do
          current_seconds = @current_started ? now - @current_started : nil
          Snapshot.new(
            name: @name, handle: @handle, done: @done, left: @left,
            session_seconds: now - @session_started,
            current_task: @current_task,
            current_task_seconds: current_seconds
          )
        end
      end
    end
  end
end
