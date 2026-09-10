# frozen_string_literal: true

module Letsdo
  # Pure policy object for per-task retry, exponential backoff and give-up.
  #
  # Letsdo::Loop stays generic and untouched; this object is wired at the
  # AgentLoop level. The loop filters attempt batches through #cooldown? and
  # records outcomes with #record_failure / #record_success.
  #
  # State is per-task (keyed by task id) and in-memory only: a fresh letsdo
  # session starts with zero failures, so a broken task yields instead of
  # hammering, and a temporarily-failing task is retried next session.
  #
  # The clock is injectable (monotonic, as in Tui::Metrics) for
  # deterministic tests.
  class RetryPolicy
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_CAP = 300.0
    DEFAULT_BASE = 10.0

    # Tunables exposed for the reconciliation logic (give-up checks).
    attr_reader :max_retries

    # @param base [Float] base backoff seconds; default wait_seconds (10.0)
    # @param cap [Float] maximum backoff seconds (default 300)
    # @param max_retries [Integer] give-up after N consecutive failures
    # @param clock [Proc] callable → monotonic epoch seconds
    def initialize(base: nil, cap: nil, max_retries: nil, clock: nil)
      @base = base || DEFAULT_BASE
      @cap = cap || DEFAULT_CAP
      @max_retries = max_retries || DEFAULT_MAX_RETRIES
      @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      @state = {}
    end

    # Consecutive failures recorded for task_key (0 when none).
    def failures(task_key)
      info = @state[task_key]
      info ? info[:failures] : 0
    end

    # Records a failed run: bumps the failure count and (re)arms the cooldown
    # deadline for exponential backoff.
    def record_failure(task_key)
      info = (@state[task_key] ||= { failures: 0, cool_until: 0 })
      info[:failures] += 1
      info[:cool_until] = cooldown_deadline(info[:failures])
      info
    end

    # Records a successful run: clears the per-task retry state.
    def record_success(task_key)
      @state.delete(task_key)
    end

    # Clears all per-task retry state (fresh session).
    def reset
      @state.clear
    end

    # Whether the task is cooling down and must be excluded from attempt
    # batches. Tasks skipped by cooldown are NOT re-recorded as failed.
    def cooldown?(task_key, now = nil)
      info = @state[task_key]
      return false unless info

      cool_until(info) > current_time(now)
    end

    # Whether the task has hit the give-up limit: it must not be attempted
    # again for the rest of the session.
    def gave_up?(task_key)
      failures(task_key) >= @max_retries
    end

    # Earliest cooldown deadline across all tasks (for a bounded wait); nil
    # when nothing is cooling down.
    def earliest_cooldown(now = nil)
      current = current_time(now)
      deadlines = @state.values.map { |info| info[:cool_until] }.select { |d| d > current }
      deadlines.empty? ? nil : deadlines.min
    end

    private

    def current_time(now)
      now.nil? ? @clock.call : now
    end

    def cooldown_deadline(failure_count)
      @clock.call + [@base * (2**(failure_count - 1)), @cap].min
    end

    def cool_until(info)
      info[:cool_until]
    end
  end
end
