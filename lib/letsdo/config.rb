# frozen_string_literal: true

require 'shellwords'

module Letsdo
  # The single place where every LETSDO_*/AGENT_* environment variable is
  # read, with exactly the defaults and precedence the CLI, PiRunner and
  # AgentLoop used to apply inline. Giving env policy one home makes it
  # testable in one place and gives future knobs (provider/backend
  # selection) a single spot to add a variable.
  #
  # The env hash is injectable for tests and defaults to the process ENV.
  class Config
    DEFAULT_WAIT_SECONDS = 10.0
    DEFAULT_PI_COMMAND = 'pi'
    DEFAULT_BACKLOG_COMMAND = 'backlog'
    DEFAULT_PROVIDER = 'backlog'

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

    # The agent's backlog assignee handle. Default: @<name> (handle = name);
    # a blank override also falls back to the derived handle.
    def assignee_handle(name)
      handle = @env['AGENT_ASSIGNEE_HANDLE']
      handle && !handle.strip.empty? ? handle : "@#{name}"
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

    # The pi command used to run agents (same literal as PiRunner::COMMAND).
    def pi_command
      @env.fetch('LETSDO_PI_COMMAND', DEFAULT_PI_COMMAND)
    end

    # The Backlog.md CLI used as the task provider.
    def backlog_command
      @env.fetch('LETSDO_BACKLOG_COMMAND', DEFAULT_BACKLOG_COMMAND)
    end

    # The task provider name. Reads LETSDO_PROVIDER with default 'backlog'.
    # An empty value falls back to 'backlog'.
    def provider
      @env['LETSDO_PROVIDER'].to_s.strip.empty? ? DEFAULT_PROVIDER : @env['LETSDO_PROVIDER'].to_s.strip
    end

    # Whether [letsdo] traces are enabled in PiRunner and AgentLoop.
    def debug?
      @env['LETSDO_DEBUG'] == '1'
    end
  end
end
