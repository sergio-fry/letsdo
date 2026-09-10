# frozen_string_literal: true

module Letsdo
  class CLI
    # TUI component assembly used by Letsdo::CLI::Builder. Kept in its own
    # module so Builder stays within the class-length limit; mirrors the
    # CLILaunch/CLIInit split pattern.
    module BuilderTui
      def run_tui(name)
        ctx = tui_context(name)
        session = Tui::Session.new(**ctx[:session])
        session.run { ctx[:loop].run }
      end

      def tui_context(name)
        parts = tui_parts(name)
        {
          loop: tui_loop(name, parts),
          session: tui_session_args(name, **parts)
        }
      end

      def tui_parts(name)
        clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        handle = assignee_handle(name)
        log = Tui::LogBuffer.new
        {
          clock: clock, handle: handle, log: log,
          metrics: tui_metrics(name, handle, clock, log),
          agent: agent_for(name, OutputStreamer.new(log: log)),
          provider: provider_for(handle),
          pause_gate: Control::PauseGate.new
        }
      end

      def tui_loop(name, parts)
        agent_loop(name, nil, agent: parts[:agent], provider: parts[:provider],
                              handle: parts[:handle], stderr: parts[:log],
                              metrics: parts[:metrics], pause_gate: parts[:pause_gate])
      end

      def tui_metrics(name, handle, clock, log)
        Tui::Metrics.new(name: name, handle: handle, clock: clock,
                         on_run_start: ->(_label) { log.divider })
      end

      def tui_session_args(name, **parts)
        {
          name: name, handle: parts[:handle], log: parts[:log], metrics: parts[:metrics],
          terminal: Tui::Terminal.new(stream: @stdout),
          input: Tui::Input.new(stdin: @stdin),
          refresh: -> { parts[:provider].call },
          wait_seconds: wait_seconds, clock: parts[:clock],
          pause_gate: parts[:pause_gate], runner: -> { parts[:agent].runner }
        }
      end
    end

    # Owns all component assembly for running an agent (TASK-54): builds the
    # streamer, agent, backlog provider, orchestrator loop and the whole TUI,
    # and decides plain vs TUI mode via stdout/stdin TTY + TERM. Parsing stays
    # in Letsdo::CLI (TASK-54); this class is the wiring half — independently
    # testable and free to grow with provider/backend selection (TASK-51/52)
    # without bloating the parser.
    class Builder
      include BuilderTui

      def initialize(env:, stdout:, stderr:, stdin: $stdin, sleeper: nil)
        @env = env
        @stdout = stdout
        @stderr = stderr
        @stdin = stdin
        @sleeper = sleeper
        @config = Config.new(env: env)
        @root = @config.root
      end

      # Runs <name> in plain or TUI mode; returns the process exit code.
      def run(name)
        store = PromptStore.new(root: @root)
        announce_default_prompt(name, store) if store.read(name).nil?
        tui? ? run_tui(name) : run_plain(name)
      end

      private

      def run_plain(name)
        streamer = OutputStreamer.new(stdout: @stdout, stderr: @stderr)
        agent_loop(name, streamer, stderr: @stderr).run
      end

      def agent_for(name, streamer)
        Agent.new(name: name, root: @root, flags: parse_pi_flags, streamer: streamer,
                  command: pi_command)
      end

      def provider_for(handle)
        Providers::Backlog.new(handle: handle, command: backlog_command, cwd: @root,
                               env: ENV.to_h.merge(@env))
      end

      def agent_loop(name, streamer, **opts)
        handle = opts[:handle] || assignee_handle(name)
        agent = opts[:agent] || agent_for(name, streamer)
        provider = opts[:provider] || provider_for(handle)
        AgentLoop.new(name: name, handle: handle, agent: agent,
                      task_provider: -> { provider.call },
                      wait_seconds: wait_seconds, sleeper: @sleeper, stderr: opts[:stderr],
                      metrics: opts[:metrics], pause_gate: opts[:pause_gate],
                      watcher: backlog_watcher)
      end

      def backlog_watcher
        Watcher.new(path: File.join(@root, 'backlog'), poll_seconds: wait_seconds)
      end

      # One-time fallback notification (before the first loop message): names
      # the exact path checked and the placement hint. The agent still starts
      # — Letsdo::Agent falls back to the built-in default prompt itself.
      def announce_default_prompt(name, store)
        @stderr.puts("letsdo: no prompt for #{name} at #{store.agent_path(name)}")
        @stderr.puts("letsdo: using the built-in default prompt (create a prompt file with 'letsdo #{name} --init')")
      end

      def tui?
        @stdout.tty? && @stdin.tty? && @env['TERM'].to_s != 'dumb'
      end

      def assignee_handle(name)
        @config.assignee_handle(name)
      end

      def backlog_command
        @config.backlog_command
      end

      def wait_seconds
        @config.wait_seconds
      end

      def pi_command
        @config.pi_command
      end

      def parse_pi_flags
        @config.pi_flags
      end
    end
  end
end
