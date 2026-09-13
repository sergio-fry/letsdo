# frozen_string_literal: true

module Letsdo
  # The identity preamble letsdo injects into every agent's system prompt on
  # launch (TASK-85). The launcher already knows the agent name and its
  # backlog assignee handle; the prompt template may not. Injecting the two
  # facts unconditionally keeps every agent aware of who it is and which
  # tasks are its own — independent of the template content, for the
  # built-in default prompt and for every custom agents/<name>.md alike.
  #
  # The handle is Config#assignee_handle, so the identity an agent reads
  # matches the handle its backlog tasks are assigned to.
  module AgentIdentity
    # The identity block prepended to a prompt. It ends with a blank line so
    # the original prompt keeps its own heading structure.
    #
    # @param name [String] agent name (also the backlog assignee name)
    # @param handle [String] backlog assignee handle (Config#assignee_handle)
    # @return [String]
    def self.preamble(name:, handle:)
      <<~TEXT
        # Your identity

        You are the agent `#{name}`. Your backlog assignee handle is `#{handle}`:
        the tasks assigned to `#{handle}` are yours to work. Identify yourself
        as this agent and use this handle in every tracked artifact you write.

      TEXT
    end

    # Prepends the identity block to a prompt, leaving the prompt itself
    # untouched.
    #
    # @param prompt [String] the agent's system prompt (file or default)
    # @param name [String] agent name
    # @param handle [String] backlog assignee handle
    # @return [String] prompt with the identity block at the very top
    def self.inject(prompt, name:, handle:)
      "#{preamble(name: name, handle: handle)}#{prompt}"
    end
  end
end
