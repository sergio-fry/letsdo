# frozen_string_literal: true

require "shellwords"

module Letsdo
  # Command-line argument parsing and running a single agent.
  #
  # CLI keeps the scaffold contract (TASK-20) and adds agent launching:
  #   letsdo                       — usage and agent list, exit code 1;
  #   letsdo --version             — version, exit code 0;
  #   letsdo --help                — usage, exit code 0;
  #   letsdo <name>                — read agents/<name>.md, run pi,
  #                                    exit code of pi;
  #   letsdo <unknown name>        — "Unknown agent: <name>" + list,
  #                                    exit code 1.
  #   letsdo <unknown option>      — "letsdo: unknown option: X" + usage,
  #                                    exit code 1.
  #
  # Environment:
  #   LETSDO_ROOT         project root (agents/ lives there); default — pwd.
  #   LETSDO_PI_FLAGS     extra pi flags (split on whitespace; if unset —
  #                       AGENT_PI_FLAGS is used for bin/agent compatibility).
  #   LETSDO_PI_COMMAND   the pi command (default "pi"); overridable for
  #                       tests/fake pi.
  class CLI
    USAGE = "Usage: letsdo <agent_name>"
    AGENTS_HEADER = "Available agents:"

    # @param argv [Array<String>] command-line arguments
    # @param env [Hash] process environment (LETSDO_ROOT, LETSDO_PI_FLAGS,
    #        AGENT_PI_FLAGS); injected in tests
    # @param stdout [IO] stream for normal output (usage, --help, list)
    # @param stderr [IO] stream for service output
    # @return [Integer] exit code: 0 — success, 1 — error, otherwise — pi exit code
    def self.run(argv, env: ENV, stdout: $stdout, stderr: $stderr)
      new(env: env, stdout: stdout, stderr: stderr).run(argv)
    end

    def initialize(env:, stdout:, stderr:)
      @env = env
      @stdout = stdout
      @stderr = stderr
      @root = env.fetch("LETSDO_ROOT", Dir.pwd)
    end

    # @param argv [Array<String>] command-line arguments
    # @return [Integer] exit code
    def run(argv)
      arg = argv[0]
      case arg
      when "--version", "-v"
        @stdout.puts(VERSION)
        0
      when "--help", "-h"
        print_usage(@stdout)
        0
      when nil
        print_usage(@stderr)
        1
      else
        if arg.start_with?("-")
          @stderr.puts("letsdo: unknown option: #{arg}")
          print_usage(@stderr)
          1
        else
          run_agent(arg)
        end
      end
    end

    private

    def run_agent(name)
      streamer = OutputStreamer.new(stdout: @stdout, stderr: @stderr)
      agent = Agent.new(name: name, root: @root, flags: parse_pi_flags, streamer: streamer,
                        command: pi_command)
      agent.run
    rescue UnknownAgentError => e
      @stderr.puts(e.message)
      print_agents
      1
    end

    def pi_command
      @env.fetch("LETSDO_PI_COMMAND", PiRunner::COMMAND)
    end

    def print_usage(stream)
      stream.puts(USAGE)
      print_agents
    end

    def print_agents
      @stdout.puts(AGENTS_HEADER)
      PromptStore.new(root: @root).list.each { |name| @stdout.puts("  #{name}") }
    end

    # LETSDO_PI_FLAGS → array of flags; empty value = no flags.
    # For bin/agent compatibility, when LETSDO_PI_FLAGS is absent
    # AGENT_PI_FLAGS is used.
    def parse_pi_flags
      value = @env["LETSDO_PI_FLAGS"].to_s
      value = @env["AGENT_PI_FLAGS"].to_s if value.strip.empty?
      return [] if value.strip.empty?

      Shellwords.split(value)
    end
  end
end