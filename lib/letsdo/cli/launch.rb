# frozen_string_literal: true

module Letsdo
  # Builds the agent, provider, and orchestrator loop for CLI run paths.
  module CLILaunch
    private

    def run_agent_plain(name)
      streamer = OutputStreamer.new(stdout: @stdout, stderr: @stderr)
      agent_loop(name, streamer, stderr: @stderr).run
    end

    def run_agent_tui(name)
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

    def agent_for(name, streamer)
      Agent.new(name: name, root: @root, flags: parse_pi_flags, streamer: streamer,
                command: pi_command)
    end

    def provider_for(handle)
      BacklogTasks.new(handle: handle, command: backlog_command, cwd: @root,
                       env: ENV.to_h.merge(@env))
    end

    def agent_loop(name, streamer, **opts)
      handle = opts[:handle] || assignee_handle(name)
      agent = opts[:agent] || agent_for(name, streamer)
      provider = opts[:provider] || provider_for(handle)
      AgentLoop.new(name: name, handle: handle, agent: agent,
                    task_provider: -> { provider.call },
                    wait_seconds: wait_seconds, sleeper: @sleeper, stderr: opts[:stderr],
                    metrics: opts[:metrics], pause_gate: opts[:pause_gate])
    end
  end
end
