# frozen_string_literal: true

require_relative 'agent_loop/tasks'

module Letsdo
  # The orchestrator loop wired to the real environment for `letsdo <name>`.
  class AgentLoop
    include AgentLoopTasks

    STOP = :letsdo_stop
    PAUSE_POLL_SECONDS = 0.05

    def initialize(name:, handle:, task_provider:, **opts)
      @name = name
      @handle = handle
      @task_provider = task_provider
      assign_opts(opts)
    end

    def run
      @loop = build_loop
      install_signal_handlers
      debug("loop start (agent=#{@name}, handle=#{@handle}, wait=#{@wait_seconds}s)")
      run_until_stopped
      debug('loop stopped')
      @stderr.puts('letsdo: stopped')
      0
    ensure
      close_watcher
      restore_signal_handlers
    end

    def close_watcher
      @watcher&.close
    end

    def debug(message)
      warn("[letsdo] loop: #{message}") if @debug
    end

    # Stop the running backend immediately.  The signal handler is
    # invoked from the main thread (Ruby 4.0) or from a dedicated signal
    # thread (3.x fallback via AGENT_SIGNAL_THREAD=1).  Thread.raise
    # works reliably on CRuby 4.0: M:N fibers make threads interruptible
    # everywhere, so a trap handler may safely raise Letsdo::Stopped on
    # the main thread to unwind the current run.
    def on_signal(_signum)
      @agent&.backend&.terminate_now
      raise Letsdo::Stopped
    end

    private

    def assign_opts(opts)
      @agent = opts[:agent]
      @run_one = opts[:run_one] || ->(_task) { @agent.run }
      @wait_seconds = opts.fetch(:wait_seconds, 10.0)
      @stderr = opts.fetch(:stderr, $stderr)
      assign_control_opts(opts)
    end

    def assign_control_opts(opts)
      @metrics = opts[:metrics]
      @pause_gate = opts[:pause_gate]
      @debug = resolve_debug(opts)
      @watcher = opts[:watcher] || (Watcher.new(path: opts[:watch_path]) if opts[:watch_path])
      # Precedence is deliberate: an explicitly injected sleeper always wins
      # over the watcher idle path — tests inject a stop/control sleeper that
      # must never be bypassed by a configured watcher (TASK-84).
      @sleeper = opts[:sleeper] || watcher_sleeper || ->(seconds) { sleep(seconds) }
    end

    def resolve_debug(opts)
      return opts[:debug] unless opts[:debug].nil?

      (opts[:config] || Config.new).debug?
    end

    def watcher_sleeper
      @watcher && ->(seconds) { @watcher.wait(seconds) }
    end

    def run_until_stopped
      catch(STOP) { @loop.run }
    rescue Letsdo::Stopped
      debug('stopped by signal')
    end

    def build_loop
      Letsdo::Loop.new(
        task_provider: wrapped_provider,
        run_task: wrapped_run,
        wait_seconds: @wait_seconds,
        sleeper: @sleeper
      )
    end

    def install_signal_handlers
      Signal.trap('SIGINT', method(:on_signal))
      Signal.trap('SIGTERM', method(:on_signal))
      Signal.trap('SIGHUP', method(:on_signal))
    end

    def restore_signal_handlers
      Signal.trap('SIGINT', 'DEFAULT')
      Signal.trap('SIGTERM', 'DEFAULT')
      Signal.trap('SIGHUP', 'DEFAULT')
    end
  end
end
