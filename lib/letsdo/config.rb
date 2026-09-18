# frozen_string_literal: true

require 'shellwords'

module Letsdo
  # The single place where every LETSDO_*/AGENT_* environment variable is
  # read, with exactly the defaults and precedence the CLI, the Pi backend
  # and AgentLoop used to apply inline. Giving env policy one home makes it
  # testable in one place and gives future knobs (provider/backend
  # selection) a single spot to add a variable.
  #
  # The env hash is injectable for tests and defaults to the process ENV.
  class Config
    DEFAULT_WAIT_SECONDS = 10.0
    DEFAULT_PI_COMMAND = 'pi'
    DEFAULT_BACKLOG_COMMAND = 'backlog'
    DEFAULT_PROVIDER = 'backlog'
    DEFAULT_BACKEND = 'pi'
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_RETRY_CAP = 300.0

    def initialize(env: ENV)
      @env = env
    end

    # Project root with agents/ (and where the backlog CLI finds backlog/).
    def root
      @env.fetch('LETSDO_ROOT', Dir.pwd)
    end

    # Extra pi flags, split on whitespace. LETSDO_PI_FLAGS wins; when empty,
    # AGENT_PI_FLAGS is the fallback (bin/agent-loop compatibility).
    def pi_flags
      value = @env['LETSDO_PI_FLAGS'].to_s
      value = @env['AGENT_PI_FLAGS'].to_s if value.strip.empty?
      return [] if value.strip.empty?

      Shellwords.split(value)
    end

    # The agent's backlog assignee name. Default: the bare agent name —
    # the tracker stores bare names ('developer'); the '@' prefix is
    # prompt-only notation (TASK-96). AGENT_ASSIGNEE_HANDLE overrides for
    # legacy setups (used verbatim; a @-prefixed value still matches after
    # normalization in the provider, but `letsdo doctor` warns about it);
    # a blank override also falls back to the derived bare name.
    def assignee_handle(name)
      assignee_handle_override || name.to_s
    end

    # Raw AGENT_ASSIGNEE_HANDLE (nil when unset or blank) — `letsdo
    # doctor` uses it to warn about a legacy @-prefixed override instead
    # of it silently missing every bare-named task.
    def assignee_handle_override
      value = @env['AGENT_ASSIGNEE_HANDLE']
      value && !value.strip.empty? ? value : nil
    end

    # Retry interval when no tasks are open. LETSDO_WAIT_SECONDS wins, then
    # AGENT_WAIT_SECONDS; an invalid value falls back to the default.
    def wait_seconds
      value = @env['LETSDO_WAIT_SECONDS'].to_s.strip
      value = @env['AGENT_WAIT_SECONDS'].to_s.strip if value.empty?
      return DEFAULT_WAIT_SECONDS if value.empty?

      Float(value)
    rescue ArgumentError, TypeError
      DEFAULT_WAIT_SECONDS
    end

    # The pi command used to run agents (same literal as Backends::Pi::COMMAND).
    def pi_command
      @env.fetch('LETSDO_PI_COMMAND', DEFAULT_PI_COMMAND)
    end

    # The Backlog.md CLI used as the task provider.
    def backlog_command
      @env.fetch('LETSDO_BACKLOG_COMMAND', DEFAULT_BACKLOG_COMMAND)
    end

    # Executable search path, used by `letsdo doctor` to resolve the
    # configured command names. It lives here so doctor code never reads
    # ENV directly (TASK-71).
    def path
      @env.fetch('PATH', '')
    end

    # Environment for CLI child processes spawned outside the builder
    # (the doctor's handle-less provider): the process environment
    # overlaid with the injected env, so shebang PATH resolution and test
    # scenario variables both keep working (TASK-96).
    def child_env
      ENV.to_h.merge(@env)
    end

    # The task provider name. Reads LETSDO_PROVIDER with default 'backlog'.
    # An empty value falls back to 'backlog'.
    def provider
      @env['LETSDO_PROVIDER'].to_s.strip.empty? ? DEFAULT_PROVIDER : @env['LETSDO_PROVIDER'].to_s.strip
    end

    # The AI backend name. Reads LETSDO_BACKEND with default 'pi'.
    # An empty value falls back to 'pi'.
    def backend
      @env['LETSDO_BACKEND'].to_s.strip.empty? ? DEFAULT_BACKEND : @env['LETSDO_BACKEND'].to_s.strip
    end

    # Whether [letsdo] traces are enabled in the Pi backend and AgentLoop.
    def debug?
      @env['LETSDO_DEBUG'] == '1'
    end

    # Whether per-task elapsed is written back into the task record as a
    # backlog comment at session stop (TASK-70). Opt-in: only the literal
    # '1' enables it, so no task file is ever modified by default.
    def task_time_comment?
      @env['LETSDO_TASK_TIME_COMMENT'] == '1'
    end

    # Give-up after N consecutive failed runs of the same task in a session
    # (default 3). Any invalid value falls back to the default.
    def max_retries
      value = @env['LETSDO_MAX_RETRIES'].to_s.strip
      return DEFAULT_MAX_RETRIES if value.empty?

      Integer(value)
    rescue ArgumentError, TypeError
      DEFAULT_MAX_RETRIES
    end

    # Base backoff seconds for the first retry; doubles per failure.
    # Default = LETSDO_WAIT_SECONDS (the loop poll interval). An invalid
    # value falls back to that default.
    def retry_base
      value = @env['LETSDO_RETRY_BASE'].to_s.strip
      value.empty? ? wait_seconds : Float(value)
    rescue ArgumentError, TypeError
      wait_seconds
    end

    # Maximum backoff seconds (default 300). An invalid value falls back
    # to the default.
    def retry_cap
      value = @env['LETSDO_RETRY_CAP'].to_s.strip
      return DEFAULT_RETRY_CAP if value.empty?

      Float(value)
    rescue ArgumentError, TypeError
      DEFAULT_RETRY_CAP
    end
  end
end
