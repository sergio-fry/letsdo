# frozen_string_literal: true

require_relative "lib/letsdo/version"

Gem::Specification.new do |spec|
  spec.name    = "letsdo"
  spec.version = Letsdo::VERSION
  spec.authors = ["Sergei O. Udalov"]
  spec.email   = ["udalov.x@mail.ru"]

  spec.summary     = "Локальный агент-работник задач Backlog.md/markdown"
  spec.description = "letsdo — локальный агент-работник задач Backlog.md/markdown. " \
                     "ООП-структура: Letsdo::PromptStore (agents/), Letsdo::OutputStreamer " \
                     "и Letsdo::PiRunner (pi --mode json), Letsdo::Agent (один прогон), " \
                     "Letsdo::Loop (цикл оркестратора), Letsdo::CLI. Тесты на Minitest. " \
                     "В будущем выделяется в отдельный репозиторий."
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.0"

  # RubyGems разрешает executables относительно bindir: литеральное значение
  # "bin/letsdo" заставило бы gem build искать bin/bin/letsdo. Каноническая
  # форма: bindir="bin" + executables=["letsdo"] — исполняемый файл джема
  # это bin/letsdo, в PATH он попадает как команда letsdo.
  spec.files         = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.bindir        = "bin"
  spec.executables   = ["letsdo"]
  spec.require_paths = ["lib"]

  spec.metadata["rubygems_mfa_required"] = "true"
end