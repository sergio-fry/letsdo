# frozen_string_literal: true

module Letsdo
  # A single agent run: reads the prompt from agents/<name>.md by agent name
  # (falling back to the built-in default prompt when the file is missing),
  # prepends the agent's identity (name + backlog assignee handle, TASK-85)
  # and delegates to the injected backend_factory. Returns the backend exit
  # code. There are no unknown agents -- every name runs, with the file
  # prompt when present and with Letsdo::DefaultPrompt::TEXT otherwise.
  #
  # This is the logic of one bin/agent run: a prompt store + an output
  # streamer + a backend factory. The orchestrator (a loop while tasks
  # exist) lives in Letsdo::Loop.
  class Agent
    # @param name [String] agent name (agents/<name>.md)
    # @param root [String] project root (agents/ lives there)
    # @param backend_factory [Proc] callable(prompt:, streamer:, model:) -> backend
    #        The factory creates a fresh backend for each run.  The prompt
    #        is read from PromptStore before the call; model comes from the
    #        agent's front-matter config (nil when absent).  All flag/
    #        command/env wiring is the factory's job -- Agent keeps no pi
    #        vocabulary.
    # @param streamer [OutputStreamer] where to print output (by default
    #        the real stdout/stderr)
    # @param handle [String, nil] the agent's backlog assignee
    #        (Config#assignee_handle). Defaults to the bare <name>
    #        (TASK-96); the launcher passes the resolved assignee so the
    #        injected identity always matches what the backlog tasks are
    #        assigned to.
    def initialize(name:, root:, backend_factory:, streamer: nil, handle: nil)
      @name = name
      @root = root
      @backend_factory = backend_factory
      @streamer = streamer || OutputStreamer.new
      @handle = handle || name.to_s
    end

    # The backend of the last/current run -- lets the orchestrator
    # terminate a running backend when the loop is stopped.
    attr_reader :backend

    # Runs the agent once.
    #
    # @return [Integer] backend exit code
    def run
      prompt = prompt_store.read(@name) || Letsdo::DefaultPrompt::TEXT
      prompt = Letsdo::AgentIdentity.inject(prompt, name: @name, handle: @handle)
      model  = prompt_store.config(@name)[:model]
      @backend = @backend_factory.call(prompt: prompt, streamer: @streamer,
                                       model: model)
      @backend.run
    end

    private

    def prompt_store
      @prompt_store ||= PromptStore.new(root: @root)
    end
  end
end
