# frozen_string_literal: true

module Letsdo
  # Один прогон агента: по имени читает промпт из .agents/<имя>.md и
  # запускает pi с этим промптом. Возвращает код выхода pi.
  #
  # Это логика одного прогона bin/agent: хранилище промптов + стример вывода
  # + раннер pi. Оркестратор (цикл, пока есть задачи) — в Letsdo::Loop.
  class Agent
    # @param name [String] имя агента (.agents/<name>.md)
    # @param root [String] корень проекта (там лежит .agents/)
    # @param flags [Array<String>] дополнительные флаги pi
    # @param streamer [OutputStreamer] куда печатать вывод (по умолчанию
    #        настоящие stdout/stderr)
    # @param command [String] команда pi (переопределяема для тестов)
    def initialize(name:, root:, flags: [], streamer: nil, command: PiRunner::COMMAND)
      @name = name
      @root = root
      @flags = flags
      @streamer = streamer || OutputStreamer.new
      @command = command
    end

    # Запускает агента один раз.
    #
    # @return [Integer] код выхода pi
    # @raise [UnknownAgentError] если агента нет в .agents/
    def run
      prompt = prompt_store.read(@name)
      PiRunner.new(prompt: prompt, flags: @flags, streamer: @streamer, command: @command).run
    end

    private

    def prompt_store
      @prompt_store ||= PromptStore.new(root: @root)
    end
  end
end