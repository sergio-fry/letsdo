# frozen_string_literal: true

require_relative 'cli/init'
require_relative 'cli/builder'

module Letsdo
  # Command-line argument parsing and running an agent orchestrator loop.
  #
  # CLI keeps the scaffold contract (TASK-20) and adds agent launching:
  #   letsdo                       — usage and agent list, exit code 1;
  #   letsdo --version             — version, exit code 0;
  #   letsdo --help                — usage, exit code 0;
  #   letsdo <name>                — run the <name> agent in the orchestrator
  #                                    loop until SIGINT/SIGTERM;
  #   letsdo <name> (no prompt)    — same, but on the built-in default prompt;
  #                                    one-time notification on stderr
  #                                    (path checked + 'letsdo <name> --init' hint);
  #   letsdo <name> --init         — create agents/<name>.md with the starter
  #                                    default prompt, never runs the agent;
  #   letsdo --init <name>         — same, flag-first form;
  #   letsdo <unknown option>      — "letsdo: unknown option: X" + usage, exit 1.
  class CLI
    include CLIInit

    USAGE = 'Usage: letsdo <agent_name>'
    AGENTS_HEADER = 'Available agents:'

    def self.run(argv, **opts)
      new(env: opts.fetch(:env, ENV), stdout: opts.fetch(:stdout, $stdout),
          stderr: opts.fetch(:stderr, $stderr), stdin: opts.fetch(:stdin, $stdin),
          sleeper: opts[:sleeper]).run(argv)
    end

    def initialize(env:, stdout:, stderr:, stdin: $stdin, sleeper: nil)
      @stdout = stdout
      @stderr = stderr
      @root = Config.new(env: env).root
      @builder = Builder.new(env: env, stdout: stdout, stderr: stderr,
                             stdin: stdin, sleeper: sleeper)
    end

    def run(argv)
      arg = argv[0]
      return print_version if version_flag?(arg)
      return print_help if help_flag?(arg)
      return usage_error if arg.nil?
      return init_command(argv) if argv.include?('--init')
      return unknown_option(arg) if arg.start_with?('-')

      run_agent(arg)
    end

    private

    def run_agent(arg)
      @builder.run(arg)
    rescue Letsdo::BackendUnavailableError => e
      @stderr.puts("letsdo: #{e.message}")
      2
    end

    def version_flag?(arg)
      ['--version', '-v'].include?(arg)
    end

    def help_flag?(arg)
      ['--help', '-h'].include?(arg)
    end

    def print_version
      @stdout.puts(VERSION)
      0
    end

    def print_help
      print_usage(@stdout)
      0
    end

    def usage_error
      print_usage(@stderr)
      1
    end

    def unknown_option(arg)
      @stderr.puts("letsdo: unknown option: #{arg}")
      print_usage(@stderr)
      1
    end

    def print_usage(stream)
      stream.puts(USAGE)
      print_agents
    end

    def print_agents
      @stdout.puts(AGENTS_HEADER)
      PromptStore.new(root: @root).list.each { |name| @stdout.puts("  #{name}") }
    end
  end
end
