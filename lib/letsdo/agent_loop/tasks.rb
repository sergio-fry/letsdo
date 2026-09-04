# frozen_string_literal: true

module Letsdo
  # Provider reporting and per-task run wrapping for AgentLoop.
  module AgentLoopTasks
    private

    def wrapped_provider
      lambda do
        tasks = @task_provider.call
        @metrics&.provider_result(tasks&.length)
        report_provider(tasks)
        tasks
      end
    end

    def report_provider(tasks)
      if tasks.nil?
        debug('provider: backlog unavailable')
        @stderr.puts("letsdo: backlog unavailable, retrying in #{@wait_seconds}s")
      elsif tasks.empty?
        debug('provider: no open tasks')
        @stderr.puts("letsdo: no open tasks for #{@name}, retrying in #{@wait_seconds}s")
      else
        debug("provider: #{tasks.length} open task(s)")
        @stderr.puts("letsdo: #{@name} has #{tasks.length} open task(s)")
      end
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
    ensure
      @metrics&.run_finished
    end

    def task_label(task)
      id = task.respond_to?(:[]) ? task['id'] : nil
      return id.to_s unless id.nil? || id.to_s.empty?

      task.to_s
    end

    def wait_while_paused
      return unless @pause_gate

      @sleeper.call(AgentLoop::PAUSE_POLL_SECONDS) while @pause_gate.paused?
    end
  end
end
