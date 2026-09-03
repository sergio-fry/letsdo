# frozen_string_literal: true

require "shellwords"

module Letsdo
  # Разбор аргументов командной строки и запуск одного агента.
  #
  # CLI сохраняет контракт каркаса (TASK-20) и добавляет запуск агента:
  #   letsdo                       — usage и список агентов, код выхода 1;
  #   letsdo --version             — версия, код выхода 0;
  #   letsdo --help                — usage, код выхода 0;
  #   letsdo <имя>                 — прочитать agents/<имя>.md, запустить pi,
  #                                    код выхода pi;
  #   letsdo <незнакомое имя>      — «Неизвестный агент: <имя>» + список,
  #                                    код выхода 1.
  #   letsdo <неизвестная опция>   — «летсду: неизвестная опция: X» + usage,
  #                                    код выхода 1.
  #
  # Окружение:
  #   LETSDO_ROOT         корень проекта (там лежит agents/); по умолчанию — pwd.
  #   LETSDO_PI_FLAGS     дополнительные флаги pi (разбиваются по словам; если не
  #                       задан — берётся AGENT_PI_FLAGS для совместимости с
  #                       bin/agent).
  #   LETSDO_PI_COMMAND   команда pi (по умолчанию "pi"); переопределяема для
  #                       тестов/фейковых pi.
  class CLI
    USAGE = "Использование: letsdo <имя_агента>"
    AGENTS_HEADER = "Доступные агенты:"

    # @param argv [Array<String>] аргументы командной строки
    # @param env [Hash] окружение процесса (LETSDO_ROOT, LETSDO_PI_FLAGS,
    #        AGENT_PI_FLAGS); инжектируется в тестах
    # @param stdout [IO] поток для нормального вывода (usage, --help, список)
    # @param stderr [IO] поток для служебного вывода
    # @return [Integer] код выхода: 0 — успех, 1 — ошибка, иначе — код выхода pi
    def self.run(argv, env: ENV, stdout: $stdout, stderr: $stderr)
      new(env: env, stdout: stdout, stderr: stderr).run(argv)
    end

    def initialize(env:, stdout:, stderr:)
      @env = env
      @stdout = stdout
      @stderr = stderr
      @root = env.fetch("LETSDO_ROOT", Dir.pwd)
    end

    # @param argv [Array<String>] аргументы командной строки
    # @return [Integer] код выхода
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
          @stderr.puts("letsdo: неизвестная опция: #{arg}")
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

    # LETSDO_PI_FLAGS → массив флагов; пустое значение = без флагов.
    # Для совместимости с bin/agent при отсутствии LETSDO_PI_FLAGS
    # используется AGENT_PI_FLAGS.
    def parse_pi_flags
      value = @env["LETSDO_PI_FLAGS"].to_s
      value = @env["AGENT_PI_FLAGS"].to_s if value.strip.empty?
      return [] if value.strip.empty?

      Shellwords.split(value)
    end
  end
end