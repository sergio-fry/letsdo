# frozen_string_literal: true

require_relative 'session_recorder/jsonl_writer'

module Letsdo
  # A mode-independent session metrics recorder. It receives the same
  # loop-driver events as the TUI metrics facade, records per-run outcomes
  # and durations, and can optionally emit a JSONL event stream.
  #
  # The recorder is intentionally free of TUI dependencies so it can be
  # used in plain mode, TUI mode, or embedded contexts.
  class SessionRecorder
    Run = Struct.new(:task_id, :started_mono, :finished_mono, :elapsed_s,
                     :exit_code, :outcome, keyword_init: true)

    Summary = Struct.new(:done, :failed, :interrupted, :left, :session_s,
                         :active_s, :waiting_s, :avg_s, :runs,
                         keyword_init: true)

    MAX_SUMMARY_RUNS = 10

    HEADLINE = 'letsdo: session: %<done>d done, %<failed>d failed, ' \
               '%<interrupted>d interrupted, %<left>s left open, %<session>s ' \
               '(%<active>s in runs, %<waiting>s waiting, avg %<avg>s)'

    # Rendering of the human-readable stop summary (TASK-63 C3). Kept nested
    # so SessionRecorder stays within the class-length limit.
    module SummaryFormat
      private

      def headline(summary)
        left = summary.left.nil? ? 'unknown' : summary.left
        format(HEADLINE, done: summary.done, failed: summary.failed,
                         interrupted: summary.interrupted, left: left,
                         session: format_duration(summary.session_s),
                         active: format_duration(summary.active_s),
                         waiting: format_duration(summary.waiting_s),
                         avg: format_duration(summary.avg_s))
      end

      def run_lines(summary)
        lines = summary.runs.first(MAX_SUMMARY_RUNS).map { |run| format_run(run) }
        return lines unless summary.runs.length > MAX_SUMMARY_RUNS

        lines << "letsdo:   … and #{summary.runs.length - MAX_SUMMARY_RUNS} more"
      end

      def format_run(run)
        return "letsdo:   #{run.task_id} interrupted" if run.finished_mono.nil?

        outcome = run.outcome == :done ? 'done' : 'failed'
        "letsdo:   #{run.task_id} #{outcome} in #{format_duration(run.elapsed_s)}"
      end

      def format_duration(seconds)
        total = [seconds.to_f, 0.0].max.round
        minutes, secs = total.divmod(60)
        return '0s' if minutes.zero? && secs.zero?
        return "#{secs}s" if minutes.zero?

        "#{minutes}m #{secs}s"
      end
    end
    include SummaryFormat

    # @param name [String] agent name
    # @param handle [String] assignee handle
    # @param clock [Proc] monotonic clock -> seconds; default
    #        Process.clock_gettime(CLOCK_MONOTONIC)
    # @param wall_clock [Proc] wall clock -> ISO8601 UTC string; default
    #        Time.now.utc.iso8601
    # @param metrics_io [IO, nil] optional append-only JSONL target
    def initialize(name:, handle:, clock: nil, wall_clock: nil, metrics_io: nil)
      @name = name
      @handle = handle
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @wall_clock = wall_clock || -> { Time.now.utc.iso8601 }
      @writer = JsonlWriter.new(metrics_io, name: name, handle: handle, wall_clock: @wall_clock)
      @mutex = Mutex.new
      @runs = []
      @left = nil
      @session_started = @clock.call
      @session_stopped = false
    end

    # A run started for a task.
    #
    # @param task_id [String] task label
    # @return [void]
    def run_started(task_id)
      @mutex.synchronize do
        @runs << Run.new(task_id: task_id, started_mono: @clock.call)
      end
    end

    # A run finished. The last still-open run is closed with the given
    # exit code. If no run is open, this is a no-op.
    #
    # @param exit_code [Integer, nil] the run exit code
    # @return [void]
    def run_finished(exit_code = nil)
      @mutex.synchronize do
        run = @runs.reverse.find { |candidate| candidate.finished_mono.nil? }
        return unless run

        close_run(run, exit_code)
        @writer.run_finished(run)
      end
    end

    # The latest open-task count from the backlog provider.
    #
    # @param count [Integer, nil] number of open tasks; nil = the backlog
    #        state is unreadable
    # @return [void]
    def provider_result(count)
      @mutex.synchronize { @left = count }
    end

    # A point-in-time summary of the session metrics.
    #
    # waiting_s is a derived approximation: session time minus the sum of
    # run durations. It therefore also includes polling, backlog reads and
    # stop overhead, not only idle waiting for new tasks.
    #
    # @return [Summary] aggregate counts and durations
    def summary
      @mutex.synchronize { build_summary }
    end

    # Writes the session_stop JSONL event and returns the summary.
    # The event is written only once per recorder instance.
    #
    # @return [Summary]
    def session_stop
      emit = claim_stop_event
      result = summary
      @writer.session_stop(result) if emit
      result
    end

    # A human-readable summary suitable for stderr.
    #
    # @return [String]
    def summary_line
      s = summary
      lines = [headline(s)] + run_lines(s)
      lines.join("\n")
    end

    private

    def close_run(run, exit_code)
      run.finished_mono = @clock.call
      run.elapsed_s = run.finished_mono - run.started_mono
      run.exit_code = exit_code
      run.outcome = exit_code&.zero? ? :done : :failed
    end

    def build_summary
      session_s = @clock.call - @session_started
      active_s = @runs.sum { |run| run.elapsed_s || 0.0 }
      Summary.new(
        done: count_outcome(:done), failed: count_outcome(:failed),
        interrupted: @runs.count { |run| run.finished_mono.nil? }, left: @left,
        session_s: session_s, active_s: active_s, waiting_s: session_s - active_s,
        avg_s: average_done_run, runs: @runs.dup
      )
    end

    def count_outcome(outcome)
      @runs.count { |run| run.outcome == outcome }
    end

    def average_done_run
      done = @runs.select { |run| run.outcome == :done }
      return 0.0 if done.empty?

      done.sum { |run| run.elapsed_s || 0.0 } / done.size
    end

    def claim_stop_event
      @mutex.synchronize do
        return false if @session_stopped

        @session_stopped = true
        @writer.enabled?
      end
    end
  end
end
