# frozen_string_literal: true

require 'json'

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
      @metrics_io = metrics_io
      @mutex = Mutex.new
      @runs = []
      @left = nil
      @session_started = @clock.call
      @session_stopped = false
      write_jsonl_event('session_start')
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

        run.finished_mono = @clock.call
        run.elapsed_s = run.finished_mono - run.started_mono
        run.exit_code = exit_code
        run.outcome = exit_code == 0 ? :done : :failed
        write_jsonl_event('run_finished', run)
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
    # @return [Summary] aggregate counts and durations
    def summary
      @mutex.synchronize do
        now = @clock.call
        session_s = now - @session_started
        active_s = @runs.sum { |run| run.elapsed_s || 0.0 }
        done_runs = @runs.select { |run| run.outcome == :done }
        avg_s = done_runs.empty? ? 0.0 : done_runs.sum { |run| run.elapsed_s || 0.0 } / done_runs.size

        Summary.new(
          done: @runs.count { |run| run.outcome == :done },
          failed: @runs.count { |run| run.outcome == :failed },
          interrupted: @runs.count { |run| run.finished_mono.nil? },
          left: @left,
          session_s: session_s,
          active_s: active_s,
          waiting_s: session_s - active_s,
          avg_s: avg_s,
          runs: @runs.dup
        )
      end
    end

    # Writes the session_stop JSONL event and returns the summary.
    # The event is written only once per recorder instance.
    #
    # @return [Summary]
    def session_stop
      write_event = false
      @mutex.synchronize do
        write_event = @metrics_io && !@session_stopped
        @session_stopped = true
      end
      s = summary
      write_jsonl_event('session_stop', s) if write_event
      s
    end

    # A human-readable summary suitable for stderr.
    #
    # @return [String]
    def summary_line
      s = summary
      lines = []

      left_text = s.left.nil? ? 'unknown' : s.left
      lines << format(
        'letsdo: session: %{done} done, %{failed} failed, %{interrupted} interrupted, ' \
        '%{left} left open, %{session} (%{active} in runs, %{waiting} waiting, avg %{avg})',
        done: s.done,
        failed: s.failed,
        interrupted: s.interrupted,
        left: left_text,
        session: format_duration(s.session_s),
        active: format_duration(s.active_s),
        waiting: format_duration(s.waiting_s),
        avg: format_duration(s.avg_s)
      )

      s.runs.first(MAX_SUMMARY_RUNS).each do |run|
        lines << format_run(run)
      end

      lines << "letsdo:   … and #{s.runs.length - MAX_SUMMARY_RUNS} more" if s.runs.length > MAX_SUMMARY_RUNS

      lines.join("\n")
    end

    private

    def format_run(run)
      return "letsdo:   #{run.task_id} interrupted" if run.finished_mono.nil?

      outcome = run.outcome == :done ? 'done' : 'failed'
      "letsdo:   #{run.task_id} #{outcome} in #{format_duration(run.elapsed_s)}"
    end

    def format_duration(seconds)
      total = [seconds.to_f, 0.0].max.round
      minutes, secs = total.divmod(60)
      return '0s' if minutes.zero? && secs.zero?

      if minutes.positive?
        "#{minutes}m #{secs}s"
      else
        "#{secs}s"
      end
    end

    def write_jsonl_event(event, run_or_summary = nil)
      return unless @metrics_io

      payload = event_payload(event, run_or_summary)
      return unless payload

      @metrics_io.puts(JSON.generate(payload))
      @metrics_io.flush if @metrics_io.respond_to?(:flush)
    end

    def event_payload(event, run_or_summary)
      case event
      when 'session_start'
        session_start_payload
      when 'run_finished'
        run_finished_payload(run_or_summary)
      when 'session_stop'
        session_stop_payload(run_or_summary)
      end
    end

    def session_start_payload
      {
        'event' => 'session_start',
        'agent' => @name,
        'handle' => @handle,
        'ts' => @wall_clock.call
      }
    end

    def run_finished_payload(run)
      {
        'event' => 'run_finished',
        'task' => run.task_id,
        'exit' => run.exit_code,
        'outcome' => run.outcome.to_s,
        'elapsed_s' => run.elapsed_s,
        'ts' => @wall_clock.call
      }
    end

    def session_stop_payload(summary)
      {
        'event' => 'session_stop',
        'agent' => @name,
        'handle' => @handle,
        'ts' => @wall_clock.call,
        'done' => summary.done,
        'failed' => summary.failed,
        'interrupted' => summary.interrupted,
        'left' => summary.left,
        'session_s' => summary.session_s,
        'runs_s' => summary.active_s
      }
    end
  end
end