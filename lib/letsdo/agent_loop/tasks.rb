# frozen_string_literal: true

module Letsdo
  # Provider reporting and per-task run wrapping for AgentLoop.
  #
  # Retry coordination happens here: the provider batch is reconciled
  # against the previous attempt (TASK-68), tasks in retry cooldown (or
  # given up) are filtered out of the batch, and each run records its
  # outcome for the next reconciliation.
  module AgentLoopTasks
    private

    def wrapped_provider
      lambda do
        tasks = @task_provider.call
        return provider_unavailable if tasks.nil?

        reconcile_attempts(tasks)
        filtered = reject_cooled_down(tasks)
        @metrics&.provider_result(filtered.length)
        report_provider(filtered, raw: tasks.length)
        filtered
      end
    end

    def report_provider(tasks, raw: nil)
      if tasks.empty?
        report_empty(raw)
        return
      end

      debug("provider: #{tasks.length} open task(s)")
      @stderr.puts("letsdo: #{@name} has #{tasks.length} open task(s)")
      report_backoff(raw - tasks.length) if raw && raw > tasks.length
    end

    def report_empty(raw)
      if raw&.positive?
        debug("provider: #{raw} open task(s) in retry backoff")
        @stderr.puts("letsdo: no runnable tasks for #{@name} (retry backoff), " \
                     "retrying in #{@wait_seconds}s")
      else
        debug('provider: no open tasks')
        @stderr.puts("letsdo: no open tasks for #{@name}, retrying in #{@wait_seconds}s")
      end
    end

    def report_backoff(skipped)
      return unless skipped.positive?

      @stderr.puts("letsdo: #{skipped} open task(s) in retry backoff")
    end

    def provider_unavailable
      debug('provider: backlog unavailable')
      @stderr.puts("letsdo: backlog unavailable, retrying in #{@wait_seconds}s")
      @metrics&.provider_result(nil)
      nil
    end

    def wrapped_run
      lambda do |task|
        wait_while_paused
        run_one_task(task)
      end
    end

    def run_one_task(task)
      label = task_label(task)
      @metrics&.run_started(label)
      @stderr.puts("letsdo: running #{@name} for #{label}")
      debug("running agent for task #{label}")
      code = @run_one.call(task)
      debug("agent run exit #{code}")
      @stderr.puts("letsdo: #{@name} exited with code #{code}") if code != 0
      @last_attempted[task_key(task)] = code
    ensure
      @metrics&.run_finished(code)
    end

    def task_label(task)
      id = task.respond_to?(:id) ? task.id : nil
      return id.to_s unless id.nil? || id.to_s.empty?

      task.to_s
    end

    def task_key(task)
      task_label(task)
    end

    def wait_while_paused
      return unless @pause_gate

      @sleeper.call(AgentLoop::PAUSE_POLL_SECONDS) while @pause_gate.paused?
    end

    # Compare tasks from the previous run batch with the fresh provider
    # result: tasks still open are failures, tasks gone are successes.
    # Tasks already in retry cooldown (or given up) were skipped and are
    # NOT re-recorded as failed.
    def reconcile_attempts(tasks)
      return unless @last_attempted

      fresh = tasks.to_h { |t| [task_key(t), true] }
      @last_attempted.each_key { |key| reconcile_key(key, fresh) }
      @last_attempted.clear
    end

    def reconcile_key(key, fresh)
      if fresh.key?(key)
        @retry_policy.record_failure(key)
        log_give_up(key) if @retry_policy.failures(key) >= @retry_policy.max_retries
      else
        @retry_policy.record_success(key)
      end
    end

    # Filters tasks that must not be attempted this batch (retry cooldown
    # or give-up). A filtered task is also dropped from the attempted-set so
    # the next reconciliation does not re-record it as failed.
    def reject_cooled_down(tasks)
      return tasks if tasks.nil? || tasks.empty?

      tasks.reject do |task|
        key = task_key(task)
        cooled = @retry_policy.cooldown?(key) || @retry_policy.gave_up?(key)
        @last_attempted.delete(key) if cooled
        cooled
      end
    end

    def log_give_up(task_key)
      message = "letsdo: giving up on #{task_key} after " \
                "#{@retry_policy.failures(task_key)} failed runs - " \
                'task stays open, next session will retry it'
      @stderr.puts(message)
    end
  end
end
