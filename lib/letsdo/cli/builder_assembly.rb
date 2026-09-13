# frozen_string_literal: true

module Letsdo
  class CLI
    # Provider and backend registries used by Letsdo::CLI::Builder: name ->
    # factory maps, injectable via the constructor for tests. Kept separate so
    # the assembly module stays within the module-length limit.
    module BuilderRegistries
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
    end

    # Registry-driven component wiring for Letsdo::CLI::Builder: the run
    # entry point, agent/provider/loop assembly and the plain-mode run path.
    # Extracted into its own module so Builder stays within the class-length
    # limit (same reason as the BuilderTui split).
    module BuilderAssembly
      include BuilderRegistries

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

      # Runs <name> in plain or TUI mode; returns the process exit code.
      def run(name)
        return 1 unless resolve_provider!
        return 1 unless resolve_backend!

        store = PromptStore.new(root: @root)
        announce_default_prompt(name, store) if store.read(name).nil?
        recorder = build_recorder(name)
        tui? ? run_tui(name, recorder) : run_plain(name, recorder)
      end

      private

      def agent_for(name, streamer)
        Agent.new(name: name, root: @root, handle: assignee_handle(name),
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
