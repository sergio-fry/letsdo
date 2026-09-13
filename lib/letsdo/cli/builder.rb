# frozen_string_literal: true

require_relative 'builder_assembly'
require_relative 'builder_metrics'

module Letsdo
  class CLI
    # TUI component assembly used by Letsdo::CLI::Builder. Kept in its own
    # module so Builder stays within the class-length limit; mirrors the
    # CLILaunch/CLIInit split pattern.
    module BuilderTui
      def run_tui(name, recorder)
        ctx = tui_context(name, recorder)
        session = Tui::Session.new(**ctx[:session])
        session.run { ctx[:loop].run }
      ensure
        recorder.session_stop
        @stderr.puts(recorder.summary_line)
      end

      def tui_context(name, recorder)
        parts = tui_parts(name, recorder)
        {
          loop: tui_loop(name, parts),
          session: tui_session_args(name, **parts)
        }
      end

      def tui_parts(name, recorder)
        clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        handle = assignee_handle(name)
        log = Tui::LogBuffer.new
        tui_parts_hash(name, recorder, clock, handle, log)
      end

      # Assembles the parts hash. The header facade (Tui::Metrics — the only
      # object answering #snapshot, which the renderer needs) and the Fanout
      # that forwards loop events to both recorder and header share the same
      # header instance (TASK-92).
      def tui_parts_hash(name, recorder, clock, handle, log)
        header = tui_metrics(name, handle, clock, log)
        provider = provider_for(handle)
        {
          clock: clock, handle: handle, log: log, header: header,
          metrics: Letsdo::Metrics::Fanout.new(recorder, header),
          agent: agent_for(name, OutputStreamer.new(log: log)),
          provider: provider,
          pause_gate: Control::PauseGate.new,
          refresh: tui_refresh(provider, recorder)
        }
      end

      # The manual 'r' refresh (TASK-42) queries the provider immediately.
      # Its return value feeds the header; the same count is handed to the
      # session recorder so the stop summary reports a fresh 'left' value
      # (TASK-69).
      def tui_refresh(provider, recorder)
        lambda do
          tasks = provider.call
          count = tasks&.length
          recorder.provider_result(count)
          count
        end
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
          name: name, handle: parts[:handle], log: parts[:log], metrics: parts[:header],
          terminal: Tui::Terminal.new(stream: @stdout),
          input: Tui::Input.new(stdin: @stdin),
          refresh: parts[:refresh],
          wait_seconds: wait_seconds, clock: parts[:clock],
          pause_gate: parts[:pause_gate], runner: -> { parts[:agent].backend }
        }
      end
    end

    # Owns all component assembly for running an agent (TASK-54): builds the
    # streamer, agent, task provider, orchestrator loop and the whole TUI,
    # and decides plain vs TUI mode via stdout/stdin TTY + TERM. Parsing stays
    # in Letsdo::CLI (TASK-54); this class is the wiring half — independently
    # testable and free to grow with provider/backend selection (TASK-51/52)
    # without bloating the parser. The wiring lives in BuilderAssembly so the
    # class stays within the class-length limit.
    class Builder
      include BuilderTui
      include BuilderAssembly
      include BuilderMetrics
    end
  end
end
