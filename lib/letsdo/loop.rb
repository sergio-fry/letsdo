# frozen_string_literal: true

module Letsdo
  # Orchestrator: while the backlog has open tasks assigned to the agent,
  # runs the agent (one run = one task). When there are no tasks — waits
  # and checks again. Stopping — only from outside: #stop (usually by a
  # SIGINT/SIGTERM handler, as in bin/agent-loop).
  #
  # The task provider and the runner are injected so the loop is testable
  # without a real backlog and pi; by default they are assembled from the
  # project environment (backlog CLI + Letsdo::Agent).
  class Loop
    # @param task_provider [Proc] callable → Array of open tasks
    #        (empty = no tasks; nil = the backlog state is unreadable,
    #        in this case the loop does not run the agent and retries)
    # @param run_task [Proc] callable(task) → agent run exit code
    # @param wait_seconds [Float] wait interval when there are no tasks
    # @param sleeper [Proc] callable(Float) → waiting (injected in tests)
    def initialize(task_provider:, run_task:, wait_seconds: 10.0, sleeper: nil)
      @task_provider = task_provider
      @run_task = run_task
      @wait_seconds = wait_seconds
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @stopped = false
    end

    # Requests a stop after the current step.
    def stop
      @stopped = true
    end

    def stopped?
      @stopped
    end

    # Runs the loop; ends only via #stop.
    #
    # @return [Integer] number of completed agent runs
    def run
      runs = 0
      until @stopped
        tasks = @task_provider.call
        if tasks.nil? || tasks.empty?
          @sleeper.call(@wait_seconds)
          next
        end

        tasks.each do |task|
          break if @stopped

          @run_task.call(task)
          runs += 1
        end
      end
      runs
    end
  end
end