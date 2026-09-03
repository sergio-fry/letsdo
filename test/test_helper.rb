# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/letsdo"

# Общая обвязка тестов джема letsdo:
#
# - требуется minitest/autorun (встроенный в Ruby, никаких внешних гемов);
#   тесты используют только простой синтаксис assert/refute — без DSL и
#   мок-фреймворков.
# - фикстуры создаются во временных каталогах (Dir.mktmpdir) и убираются
#   автоматически после каждого теста.
# - для тестов, которые запускают pi, используется фейковый исполняемый
#   скрипт test/fixtures/fake_pi (см. его шапку).

module LetsdoTestHelpers
  # Корень временного проекта: agents/ с промптами (имя => содержимое).
  #
  # @param prompts [Hash{String=>String}] имя агента → текст промпта
  # @return [String] путь к корню временного проекта
  def with_project(prompts)
    Dir.mktmpdir("letsdo-project") do |dir|
      agents_dir = File.join(dir, "agents")
      FileUtils.mkdir_p(agents_dir)
      prompts.each do |name, body|
        File.write(File.join(agents_dir, "#{name}.md"), body)
      end
      yield dir
    end
  end

  # Корень временного проекта без каталога agents/
  def with_empty_project
    Dir.mktmpdir("letsdo-project") { |dir| yield dir }
  end

  # Путь к фейковому pi.
  def fake_pi
    File.expand_path("fixtures/fake_pi", __dir__)
  end
end

class Minitest::Test
  include LetsdoTestHelpers
end