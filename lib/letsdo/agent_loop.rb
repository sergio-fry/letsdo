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
      restore_signal_handlers
    end

    def debug(message)
      warn("[letsdo] loop: #{message}") if @debug
    end

    def on_signal(_signum)
      @agent&.runner&.terminate_now
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
      @debug = opts[:debug].nil? ? ENV['LETSDO_DEBUG'] == '1' : opts[:debug]
      @sleeper = opts[:sleeper] || ->(seconds) { sleep(seconds) }
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
