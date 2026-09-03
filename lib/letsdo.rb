# frozen_string_literal: true

# Пакет Letsdo — локальный агент-работник задач Backlog.md/markdown.
#
# ООП-структура (с прицелом на перенос логики bin/agent):
#   Letsdo::Errors           - иерархия ошибок (UnknownAgentError и др.)
#   Letsdo::PromptStore      - доступ к промптам agents/*.md
#   Letsdo::OutputStreamer   - куда и как печатать текст агента и служебные строки
#   Letsdo::PiRunner         - запуск pi --mode json и разбор потока событий
#   Letsdo::Agent            - один прогон агента: промпт из agents/ + pi
#   Letsdo::Loop             - оркестратор: задачи из бэклога → прогоны → ожидание
#   Letsdo::CLI              - аргументы командной строки, usage, код выхода
#
# Точка входа — bin/letsdo (тонкая обёртка над Letsdo::CLI).

require_relative "letsdo/version"
require_relative "letsdo/errors"
require_relative "letsdo/prompt_store"
require_relative "letsdo/output_streamer"
require_relative "letsdo/pi_runner"
require_relative "letsdo/agent"
require_relative "letsdo/loop"
require_relative "letsdo/cli"