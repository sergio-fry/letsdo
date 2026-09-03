# frozen_string_literal: true

module Letsdo
  # Access to agent prompts: the agents/<name>.md directory in the project
  # root. A new agent = a new agents/<name>.md file, no code changes needed.
  class PromptStore
    AGENTS_DIR = "agents"

    # @param root [String] project root (agents/ lives there)
    def initialize(root:)
      @root = root
    end

    # Sorted list of agent names (file names without extension).
    #
    # @return [Array<String>]
    def list
      Dir.glob(File.join(agents_dir, "*.md")).sort.map { |path| File.basename(path, ".md") }
    end

    # Reads an agent prompt.
    #
    # @param name [String] agent name
    # @return [String] contents of agents/<name>.md
    # @raise [UnknownAgentError] if there is no such agent
    def read(name)
      path = File.join(agents_dir, "#{name}.md")
      raise UnknownAgentError, name unless File.file?(path)

      File.read(path)
    end

    private

    def agents_dir
      File.join(@root, AGENTS_DIR)
    end
  end
end