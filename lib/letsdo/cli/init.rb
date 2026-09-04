# frozen_string_literal: true

module Letsdo
  # The --init scaffold command (TASK-44): `letsdo <name> --init` and
  # `letsdo --init <name>` create agents/<name>.md with the starter default
  # prompt (Letsdo::DefaultPrompt::TEXT) so the agent can be customized
  # later. The agent itself is never started. PromptStore#create_agent
  # already guarantees no overwrite and nothing outside agents/ — this
  # module only maps the results to messages and exit codes.
  module CLIInit
    private

    # Creates agents/<name>.md. Success prints "created <path>" (stdout),
    # exit 0; an unsafe name or an already existing file prints the error
    # on stderr, exit 1; a missing name falls back to usage, exit 1.
    def init_command(argv)
      name = argv[0] == '--init' ? argv[1] : argv[0]
      return usage_error if name.nil?
      return init_error("invalid agent name: #{name}") if PromptStore.unsafe_name?(name)

      store = PromptStore.new(root: @root)
      return init_error("agents/#{name}.md already exists") unless store.create_agent(name, Letsdo::DefaultPrompt::TEXT)

      @stdout.puts("created #{store.agent_path(name)}")
      0
    end

    def init_error(message)
      @stderr.puts("letsdo: #{message}")
      1
    end
  end
end
