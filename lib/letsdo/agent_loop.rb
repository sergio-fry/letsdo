# frozen_string_literal: true

module Letsdo
  # The orchestrator loop wired to the real environment for `letsdo <name>`:
  #
  #   Letsdo::Loop        — while the provider gives open tasks, runs the
  #                         agent (one run = one task); no tasks (or the
  #                         backlog is unreadable) — waits and checks again;
  #   task provider       — open tasks assigned to the agent's handle
  #                         (Letsdo::BacklogTasks by default);
  #   agent run           — one Letsdo::Agent run per open task;
  #   signals             — SIGINT/SIGTERM stop the loop: a running pi child
  #                         is terminated and the process exits with 0.
  #
  # Waiting is interruptible: stop signals are delivered as
  # Letsdo::Stopped raised from the trap, so the loop unwinds right away
  # instead of waiting out the retry interval (see #on_signal).
  #
  # Service output goes to stderr: started, running <name> for <task>, no
  # open tasks / backlog unavailable with the retry interval, non-zero agent
  # exit codes, stopped.
  class AgentLoop
    STOP = :letsdo_stop

    # @param name [String] agent name (for messages)
    # @param handle [String] assignee handle of the agent (e.g. "@developer")
    # @param agent [Letsdo::Agent, nil] agent to run once per task (its
    #        current runner is terminated on stop); ignored when run_one is
    #        given
    # @param run_one [Proc, nil] callable(task) → agent exit code; by default
    #        the injected agent's #run
    # @param task_provider [Proc] callable → Array of open tasks (empty = no
    #        tasks) or nil (backlog unreadable — pause)
    # @param wait_seconds [Float] retry interval when there are no tasks
    # @param sleeper [Proc, nil] callable(Float) → waiting; injectable for
    #        deterministic stops in tests (throw Letsdo::AgentLoop::STOP)
    # @param stderr [IO] service output stream
    # @param metrics [Object, nil] optional header-metrics facade
    #        (Letsdo::Tui::Metrics in TUI mode): receives provider_result
    #        on every provider call and run_started/run_finished around
    #        each agent run; nil in plain mode, so plain behavior is
    #        byte-identical
    # @param debug [Boolean, nil] trace [letsdo] lines to stderr; nil = LETSDO_DEBUG
    def initialize(name:, handle:, agent: nil, run_one: nil, task_provider:,
                   wait_seconds: 10.0, sleeper: nil, stderr: $stderr, metrics: nil, debug: nil)
      @name = name
      @handle = handle
      @agent = agent
      @run_one = run_one || ->(_task) { @agent.run }
      @task_provider = task_provider
      @wait_seconds = wait_seconds
      @stderr = stderr
      @metrics = metrics
      @debug = debug.nil? ? ENV["LETSDO_DEBUG"] == "1" : debug
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
    end

    # Runs the loop until stopped (SIGINT/SIGTERM).
    # Runs the loop until stopped (SIGINT/SIGTERM).
    #
    # Stopping is done by raising Letsdo::Stopped from the signal handler:
    # the raise interrupts whatever the main thread is doing (reading pi
    # output, waiting for new tasks, running the backlog CLI) and unwinds
    # the loop. The handler itself only sends SIGTERM to a running pi group
    # (no waits or IO — safe from a trap) and raises.
    #
    # @return [Integer] exit code — always 0 when stopped cleanly
    def run
      @loop = build_loop
      install_signal_handlers
      debug("loop start (agent=#{@name}, handle=#{@handle}, wait=#{@wait_seconds}s)")
      begin
        catch(STOP) { @loop.run }
      rescue Letsdo::Stopped
        debug("stopped by signal")
      end
      debug("loop stopped")
      @stderr.puts("letsdo: stopped")
      0
    ensure
      restore_signal_handlers
    end

    def debug(message)
      warn("[letsdo] loop: #{message}") if @debug
    end

    # Signal handler: sends SIGTERM to a running pi group and raises
    # Letsdo::Stopped to interrupt the main thread. Nothing else — no IO,
    # no sleeps (a trap writing to a busy stream deadlocks; the pi is
    # reaped by Letsdo::PiRunner#run after the unwind).
    def on_signal(_signum)
      runner = @agent&.runner
      runner&.terminate_now
      raise Letsdo::Stopped
    end

    private

    def build_loop
      @loop = Letsdo::Loop.new(
        task_provider: wrapped_provider,
        run_task: wrapped_run,
        wait_seconds: @wait_seconds,
        sleeper: @sleeper
      )
    end

    # Messages on stderr: open task count before the batch and the wait
    # reason (no tasks vs unreadable backlog) before every wait.
    def wrapped_provider
      lambda do
        tasks = @task_provider.call
        @metrics&.provider_result(tasks.nil? ? nil : tasks.length)
        if tasks.nil?
          debug("provider: backlog unavailable")
          @stderr.puts("letsdo: backlog unavailable, retrying in #{@wait_seconds}s")
        elsif tasks.empty?
          debug("provider: no open tasks")
          @stderr.puts("letsdo: no open tasks for #{@name}, retrying in #{@wait_seconds}s")
        else
          debug("provider: #{tasks.length} open task(s)")
          @stderr.puts("letsdo: #{@name} has #{tasks.length} open task(s)")
        end
        tasks
      end
    end

    # One agent run per task; a non-zero exit code is noted but the loop
    # continues. Metrics events bracket the run so the TUI can count done
    # tasks and show the running one with its elapsed time.
    def wrapped_run
      lambda do |task|
        @metrics&.run_started(task_label(task))
        @stderr.puts("letsdo: running #{@name} for #{task_label(task)}")
        debug("running agent for task #{task_label(task)}")
        code = @run_one.call(task)
        debug("agent run exit #{code}")
        @stderr.puts("letsdo: #{@name} exited with code #{code}") if code != 0
      ensure
        @metrics&.run_finished
      end
    end

    # A human-readable label of a task for messages: the id field when
    # present, the object as-is otherwise.
    def task_label(task)
      id = task.respond_to?(:[]) ? task["id"] : nil
      return id.to_s unless id.nil? || id.to_s.empty?

      task.to_s
    end

    # The default waiting blocks only for the retry interval: a stop signal
    # interrupts it as Letsdo::Stopped raised from the trap.
    def interruptible_sleeper
      ->(seconds) { sleep(seconds) }
    end

    def install_signal_handlers
      Signal.trap("SIGINT", method(:on_signal))
      Signal.trap("SIGTERM", method(:on_signal))
    end

    def restore_signal_handlers
      Signal.trap("SIGINT", "DEFAULT")
      Signal.trap("SIGTERM", "DEFAULT")
    end
  end
end