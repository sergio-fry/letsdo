# frozen_string_literal: true

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
        {
          clock: clock, handle: handle, log: log,
          metrics: Letsdo::Metrics::Fanout.new(recorder, tui_metrics(name, handle, clock, log)),
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
          refresh: -> { tasks = parts[:provider].call; tasks ? tasks.length : nil },
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
    # without bloating the parser.
    class Builder
      include BuilderTui

      # Provider registry: maps LETSDO_PROVIDER names to factories that build
      # a provider from handle, command, cwd, and env.  Inject a custom
      # registry via the constructor for tests.
      PROVIDERS = {
        'backlog' => lambda do |handle:, command:, cwd:, env:|
          Providers::Backlog.new(handle: handle, command: command, cwd: cwd, env: env)
        end
      }.freeze

      # Backend registry: maps LETSDO_BACKEND names to factory builders that
      # take the Letsdo::Config and return a backend_factory (callable with
      # prompt:, streamer:, model:). The pi entry captures the pi command and
      # flags from Config (LETSDO_PI_COMMAND / LETSDO_PI_FLAGS with the
      # AGENT_PI_FLAGS fallback), keeping pi vocabulary out of the business
      # layer.  Inject a custom registry via the constructor for tests.
      BACKENDS = {
        'pi' => lambda do |config:|
          command = config.pi_command
          flags = config.pi_flags
          lambda { |prompt:, streamer:, model: nil|
            Letsdo::Backends::Pi.new(prompt: prompt, streamer: streamer,
                                     flags: flags, command: command,
                                     model: model, config: config)
          }
        end
      }.freeze

      def initialize(env:, stdout:, stderr:, **rest)
        @env = env
        @stdout = stdout
        @stderr = stderr
        @stdin = rest[:stdin] || $stdin
        @sleeper = rest[:sleeper]
        @config = Config.new(env: env)
        @root = @config.root
        @provider_registry = rest[:provider_registry] || PROVIDERS
        @backend_registry = rest[:backend_registry] || BACKENDS
      end

      # Returns the IO for the LETSDO_METRICS_FILE, or nil if unset or
      # unwritable. Emits a warning to stderr on invalid path.
      def metrics_io
        path = @env['LETSDO_METRICS_FILE']
        return nil if path.nil? || path.empty?

        File.open(path, 'a', encoding: 'UTF-8')
      rescue SystemCallError, IOError => e
        @stderr.puts("letsdo: cannot open metrics file #{path}: #{e.message}")
        nil
      end

      # Runs <name> in plain or TUI mode; returns the process exit code.
      def run(name)
        return 1 unless resolve_provider!
        return 1 unless resolve_backend!

        store = PromptStore.new(root: @root)
        announce_default_prompt(name, store) if store.read(name).nil?
        recorder = Letsdo::SessionRecorder.new(
          name: name,
          handle: assignee_handle(name),
          metrics_io: metrics_io
        )
        tui? ? run_tui(name, recorder) : run_plain(name, recorder)
      end

      private

      def run_plain(name, recorder)
        streamer = OutputStreamer.new(stdout: @stdout, stderr: @stderr)
        agent_loop(name, streamer, stderr: @stderr, metrics: recorder).run
      ensure
        recorder.session_stop
        @stderr.puts(recorder.summary_line)
      end

      def agent_for(name, streamer)
        Agent.new(name: name, root: @root,
                  backend_factory: @selected_backend_factory,
                  streamer: streamer)
      end

      # Resolves LETSDO_BACKEND through the backend registry once per run,
      # so both wiring paths (plain and TUI) build the Agent's
      # backend_factory through the same registry entry.  An unknown backend
      # name fails fast instead of silently falling back.
      def resolve_backend!
        builder = @backend_registry[@config.backend]
        if builder
          @selected_backend_factory = builder.call(config: @config)
          return true
        end

        @stderr.puts("letsdo: unknown AI backend: #{@config.backend}")
        false
      end

      def resolve_provider!
        @selected_provider_factory = @provider_registry[@config.provider]
        return true if @selected_provider_factory

        @stderr.puts("letsdo: unknown task provider: #{@config.provider}")
        false
      end

      def provider_for(handle)
        @selected_provider_factory.call(
          handle: handle,
          command: backlog_command,
          cwd: @root,
          env: ENV.to_h.merge(@env)
        )
      end

      def agent_loop(name, streamer, **opts)
        handle = opts[:handle] || assignee_handle(name)
        agent = opts[:agent] || agent_for(name, streamer)
        provider = opts[:provider] || provider_for(handle)
        AgentLoop.new(name: name, handle: handle, agent: agent,
                      task_provider: -> { provider.call },
                      wait_seconds: wait_seconds, sleeper: @sleeper, stderr: opts[:stderr],
                      metrics: opts[:metrics], pause_gate: opts[:pause_gate],
                      watcher: backlog_watcher, **retry_options)
      end

      def retry_options
        { retry_base: @config.retry_base, retry_cap: @config.retry_cap, max_retries: @config.max_retries }
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
    end
  end
end
