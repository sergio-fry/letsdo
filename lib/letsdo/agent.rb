# frozen_string_literal: true

module Letsdo
  # A single agent run: reads the prompt from agents/<name>.md by agent name
  # (falling back to the built-in default prompt when the file is missing)
  # and runs pi with that prompt. Returns the pi exit code. There are no
  # unknown agents — every name runs, with the file prompt when present and
  # with Letsdo::DefaultPrompt::TEXT otherwise.
  #
  # This is the logic of one bin/agent run: a prompt store + an output
  # streamer + a pi runner. The orchestrator (a loop while tasks exist)
  # lives in Letsdo::Loop.
  class Agent
    # @param name [String] agent name (agents/<name>.md)
    # @param root [String] project root (agents/ lives there)
    # @param flags [Array<String>] extra pi flags
    # @param streamer [OutputStreamer] where to print output (by default
    #        the real stdout/stderr)
    # @param command [String] the pi command (overridable for tests)
    def initialize(name:, root:, flags: [], streamer: nil, command: PiRunner::COMMAND)
      @name = name
      @root = root
      @flags = flags
      @streamer = streamer || OutputStreamer.new
      @command = command
    end

    # The runner of the last/current run — lets the orchestrator terminate
    # a running pi when the loop is stopped.
    attr_reader :runner

    # Runs the agent once.
    #
    # @return [Integer] pi exit code
    def run
      prompt = prompt_store.read(@name) || Letsdo::DefaultPrompt::TEXT
      @runner = PiRunner.new(prompt: prompt, flags: @flags, streamer: @streamer, command: @command)
      @runner.run
    end

    private

    def prompt_store
      @prompt_store ||= PromptStore.new(root: @root)
    end
  end
end
