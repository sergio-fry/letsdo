# frozen_string_literal: true

module Letsdo
  # Access to agent prompts: the agents/<name>.md directory in the project
  # root. A new agent = a new agents/<name>.md file, no code changes needed.
  class PromptStore
    AGENTS_DIR = 'agents'

    # @param root [String] project root (agents/ lives there)
    def initialize(root:)
      @root = root
    end

    # Sorted list of agent names (file names without extension).
    #
    # @return [Array<String>]
    def list
      Dir.glob(File.join(agents_dir, '*.md')).sort.map { |path| File.basename(path, '.md') }
    end

    # Reads an agent prompt. There are no unknown agents: when
    # agents/<name>.md is missing, the caller falls back to the built-in
    # default prompt (Letsdo::DefaultPrompt) and announces it (see CLI).
    #
    # @param name [String] agent name
    # @return [String, nil] contents of agents/<name>.md, nil when missing
    def read(name)
      path = agent_path(name)
      return nil unless File.file?(path)

      File.read(path)
    end

    # Absolute path of an agent's prompt file, whether or not it exists.
    #
    # @param name [String] agent name
    # @return [String] <root>/agents/<name>.md (resolved to an absolute path)
    def agent_path(name)
      File.expand_path(File.join(agents_dir, "#{name}.md"))
    end

    private

    def agents_dir
      File.join(@root, AGENTS_DIR)
    end
  end
end
