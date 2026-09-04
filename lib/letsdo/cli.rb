# frozen_string_literal: true

require 'shellwords'

module Letsdo
  # Command-line argument parsing and running an agent orchestrator loop.
  #
  # CLI keeps the scaffold contract (TASK-20) and adds agent launching:
  #   letsdo                       — usage and agent list, exit code 1;
  #   letsdo --version             — version, exit code 0;
  #   letsdo --help                — usage, exit code 0;
  #   letsdo <name>                — run the <name> agent in the orchestrator
  #                                    loop until SIGINT/SIGTERM: all open
  #                                    tasks assigned to the agent are done
  #                                    one run per task, the loop waits for
  #                                    new ones; clean exit code 0;
  #   letsdo <unknown name>        — "Unknown agent: <name>" + list,
  #                                    exit code 1.
  #   letsdo <unknown option>      — "letsdo: unknown option: X" + usage,
  #                                    exit code 1.
  #
  # Environment:
  #   LETSDO_ROOT              project root (agents/ lives there); default — pwd.
  #   LETSDO_PI_FLAGS          extra pi flags (split on whitespace; if unset —
  #                            AGENT_PI_FLAGS is used for bin/agent
  #                            compatibility).
  #   LETSDO_PI_COMMAND        the pi command (default "pi"); overridable for
  #                            tests/fake pi.
  #   AGENT_ASSIGNEE_HANDLE    the agent's backlog assignee handle; default
  #                            "@<name>" (the one rule: handle = name).
  #   LETSDO_WAIT_SECONDS      retry interval when no tasks are open (if
  #                            unset — AGENT_WAIT_SECONDS, default 10).
  #   LETSDO_BACKLOG_COMMAND   the backlog CLI command (default "backlog");
  #                            overridable for tests/fake backlog.
  class CLI
    USAGE = 'Usage: letsdo <agent_name>'
    AGENTS_HEADER = 'Available agents:'
    DEFAULT_WAIT_SECONDS = 10.0

    # @param argv [Array<String>] command-line arguments
    # @param env [Hash] process environment (LETSDO_ROOT, LETSDO_PI_FLAGS,
    #        AGENT_PI_FLAGS, AGENT_ASSIGNEE_HANDLE, LETSDO_WAIT_SECONDS,
    #        LETSDO_BACKLOG_COMMAND); injected in tests
    # @param stdout [IO] stream for normal output (usage, --help, list)
    # @param stderr [IO] stream for service output
    # @param stdin [IO] keyboard stream (the TUI reads keys from it)
    # @param sleeper [Proc, nil] waiting procedure for the loop (callable
    #        with the interval); injected in tests for deterministic stops
    # @return [Integer] exit code: 0 — success (incl. loop stop), 1 — error,
    #         otherwise — pi exit code
    def self.run(argv, env: ENV, stdout: $stdout, stderr: $stderr, stdin: $stdin, sleeper: nil)
      new(env: env, stdout: stdout, stderr: stderr, stdin: stdin, sleeper: sleeper).run(argv)
    end

    def initialize(env:, stdout:, stderr:, stdin: $stdin, sleeper: nil)
      @env = env
      @stdout = stdout
      @stderr = stderr
      @stdin = stdin
      @sleeper = sleeper
      @root = env.fetch('LETSDO_ROOT', Dir.pwd)
    end

    # @param argv [Array<String>] command-line arguments
    # @return [Integer] exit code
    def run(argv)
      arg = argv[0]
      case arg
      when '--version', '-v'
        @stdout.puts(VERSION)
        0
      when '--help', '-h'
        print_usage(@stdout)
        0
      when nil
        print_usage(@stderr)
        1
      else
        if arg.start_with?('-')
          @stderr.puts("letsdo: unknown option: #{arg}")
          print_usage(@stderr)
          1
        else
          run_agent(arg)
        end
      end
    end

    private

    def run_agent(name)
      # The prompt must exist before the loop starts: an unknown agent fails
      # fast (exit 1) instead of spinning in the loop.
      PromptStore.new(root: @root).read(name)

      if tui?
        run_agent_tui(name)
      else
        run_agent_plain(name)
      end
    rescue UnknownAgentError => e
      @stderr.puts(e.message)
      print_agents
      1
    end

    # The non-interactive path: the plain line-stream output, byte-identical
    # to the pre-TUI behavior (pipes, CI, tests, TERM=dumb).
    def run_agent_plain(name)
      streamer = OutputStreamer.new(stdout: @stdout, stderr: @stderr)
      agent = Agent.new(name: name, root: @root, flags: parse_pi_flags, streamer: streamer,
                        command: pi_command)
      handle = assignee_handle(name)
      provider = BacklogTasks.new(handle: handle, command: backlog_command, cwd: @root,
                                  env: ENV.to_h.merge(@env))
      loop = AgentLoop.new(name: name, handle: handle, agent: agent,
                           task_provider: -> { provider.call },
                           wait_seconds: wait_seconds, sleeper: @sleeper, stderr: @stderr)
      loop.run
    end

    # The interactive path: full-screen TUI over the same orchestrator loop.
    # The streamer and the loop's service messages land in one combined log
    # buffer; the loop driver feeds the header metrics facade; the session
    # controller renders everything from a background input thread and
    # restores the terminal on every exit path. The loop itself runs on the
    # calling thread exactly as in plain mode.
    def run_agent_tui(name)
      clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
      handle = assignee_handle(name)
      log = Tui::LogBuffer.new
      metrics = Tui::Metrics.new(name: name, handle: handle, clock: clock,
                                 on_run_start: ->(_label) { log.divider })
      terminal = Tui::Terminal.new(stream: @stdout)
      input = Tui::Input.new(stdin: @stdin)
      streamer = OutputStreamer.new(log: log)
      agent = Agent.new(name: name, root: @root, flags: parse_pi_flags, streamer: streamer,
                        command: pi_command)
      provider = BacklogTasks.new(handle: handle, command: backlog_command, cwd: @root,
                                  env: ENV.to_h.merge(@env))
      loop = AgentLoop.new(name: name, handle: handle, agent: agent,
                           task_provider: -> { provider.call },
                           wait_seconds: wait_seconds, sleeper: @sleeper, stderr: log,
                           metrics: metrics)
      session = Tui::Session.new(name: name, handle: handle, log: log, metrics: metrics,
                                 terminal: terminal, input: input,
                                 refresh: -> { provider.call },
                                 wait_seconds: wait_seconds, clock: clock)
      session.run { loop.run }
    end

    # The TUI is engaged only when stdout and stdin are terminals and TERM
    # is not dumb; otherwise the plain line-stream output (pipes, CI,
    # tests) — no escape codes, no TUI.
    def tui?
      @stdout.tty? && @stdin.tty? && @env['TERM'].to_s != 'dumb'
    end

    # The agent's assignee handle: AGENT_ASSIGNEE_HANDLE override, otherwise
    # the one rule — '@' + agent name.
    def assignee_handle(name)
      env_handle = @env['AGENT_ASSIGNEE_HANDLE']
      env_handle && !env_handle.strip.empty? ? env_handle : "@#{name}"
    end

    def backlog_command
      @env.fetch('LETSDO_BACKLOG_COMMAND', 'backlog')
    end

    # The retry interval when no tasks are open: LETSDO_WAIT_SECONDS, then
    # AGENT_WAIT_SECONDS (bin/agent-loop compatibility), default 10 seconds.
    def wait_seconds
      value = @env['LETSDO_WAIT_SECONDS'].to_s.strip
      value = @env['AGENT_WAIT_SECONDS'].to_s.strip if value.empty?
      return DEFAULT_WAIT_SECONDS if value.empty?

      Float(value)
    rescue ArgumentError, TypeError
      DEFAULT_WAIT_SECONDS
    end

    def pi_command
      @env.fetch('LETSDO_PI_COMMAND', PiRunner::COMMAND)
    end

    def print_usage(stream)
      stream.puts(USAGE)
      print_agents
    end

    def print_agents
      @stdout.puts(AGENTS_HEADER)
      PromptStore.new(root: @root).list.each { |name| @stdout.puts("  #{name}") }
    end

    # LETSDO_PI_FLAGS → array of flags; empty value = no flags.
    # For bin/agent compatibility, when LETSDO_PI_FLAGS is absent
    # AGENT_PI_FLAGS is used.
    def parse_pi_flags
      value = @env['LETSDO_PI_FLAGS'].to_s
      value = @env['AGENT_PI_FLAGS'].to_s if value.strip.empty?
      return [] if value.strip.empty?

      Shellwords.split(value)
    end
  end
end
