# frozen_string_literal: true

module Letsdo
  # Базовая ошибка пакета.
  class Error < StandardError; end

  # Агент с таким именем не найден в agents/.
  class UnknownAgentError < Error
    attr_reader :name

    def initialize(name)
      @name = name
      super("Неизвестный агент: #{name}")
    end
  end
end