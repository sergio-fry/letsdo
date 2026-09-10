# frozen_string_literal: true

require 'fileutils'
require 'yaml'

module Letsdo
  # Access to agent prompts: the agents/<name>.md directory in the project
  # root. A new agent = a new agents/<name>.md file, no code changes needed.
  class PromptStore
    AGENTS_DIR = 'agents'

    # Whether a name may be used as an agent prompt file name. Refuses
    # path separators (no writes outside agents/ via traversal) and the
    # dot names. Shared by create_agent and the CLI so both agree.
    #
    # @param name [String] agent name
    # @return [Boolean]
    def self.unsafe_name?(name)
      name == '.' || name == '..' || name.match?(%r{[/\\]})
    end

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

    # Parsed launch configuration for an agent.
    #
    # Returns a hash with symbolised keys. An empty hash when the file
    # is missing or has no YAML front matter.
    #
    # @param name [String] agent name
    # @return [Hash{Symbol => Object}]
    def config(name)
      path = agent_path(name)
      return {} unless File.file?(path)

      self.class.parse_front_matter(File.read(path))
    end

    # Absolute path of an agent's prompt file, whether or not it exists.
    #
    # @param name [String] agent name
    # @return [String] <root>/agents/<name>.md (resolved to an absolute path)
    def agent_path(name)
      File.expand_path(File.join(agents_dir, "#{name}.md"))
    end

    # Creates agents/<name>.md with the given content. Never raises and
    # never writes anything when the file already exists or the name is
    # unsafe (contains "/" or "\\", or is "."/"..") — returns false in
    # both cases. Otherwise mkdir_p the agents/ dir, writes the content
    # and returns true. Creation always stays inside agents/.
    #
    # @param name [String] agent name (also the would-be file name)
    # @param content [String] prompt text to write
    # @return [Boolean] true when the file was created, false otherwise
    def create_agent(name, content)
      return false if self.class.unsafe_name?(name)
      return false if File.exist?(agent_path(name))

      FileUtils.mkdir_p(agents_dir)
      File.write(agent_path(name), content)
      true
    end

    # Parses an optional YAML front matter block delimited by `---` at
    # the very start of a prompt file. Returns the keys symbolised;
    # returns an empty hash when there is no front matter or it is
    # invalid.
    #
    # @param content [String] full file content
    # @return [Hash{Symbol => Object}]
    def self.parse_front_matter(content)
      # The content must start with a `---` line followed by front matter
      # and a closing `---`.
      match = content.match(/\A---
?
(.+?)
?
---
?
/m)
      return {} unless match

      raw = match[1]
      parsed = YAML.safe_load(raw, permitted_classes: [])
      return {} unless parsed.is_a?(Hash)

      parsed.transform_keys(&:to_sym)
    rescue StandardError
      {}
    end

    private

    def agents_dir
      File.join(@root, AGENTS_DIR)
    end
  end
end
