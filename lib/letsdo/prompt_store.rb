# frozen_string_literal: true

module Letsdo
  # Доступ к промптам агентов: каталог .agents/<имя>.md в корне проекта.
  # Новый агент = новый файл .agents/<имя>.md, менять код не нужно.
  class PromptStore
    AGENTS_DIR = ".agents"

    # @param root [String] корень проекта (там лежит .agents/)
    def initialize(root:)
      @root = root
    end

    # Отсортированный список имён агентов (имена файлов без расширения).
    #
    # @return [Array<String>]
    def list
      Dir.glob(File.join(agents_dir, "*.md")).sort.map { |path| File.basename(path, ".md") }
    end

    # Читает промпт агента.
    #
    # @param name [String] имя агента
    # @return [String] содержимое .agents/<name>.md
    # @raise [UnknownAgentError] если такого агента нет
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