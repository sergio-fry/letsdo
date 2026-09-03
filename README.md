# letsdo

Локальный агент-работник задач Backlog.md/markdown.

Ruby-джем: библиотека `lib/letsdo` (ООП-структура: агенты, хранилище
промптов `agents/`, стример вывода pi, обработка ошибок, цикл оркестратора)
и исполняемый файл `bin/letsdo`. В будущем джем выделяется в отдельный
репозиторий — сейчас живёт в папке `letsdo/` корня проекта.

## Использование

Из папки `letsdo/`:

```sh
./bin/letsdo <имя>     # прочитать agents/<имя>.md и запустить pi (exit = код pi)
./bin/letsdo --version # версия джема (из lib/letsdo/version.rb), exit 0
./bin/letsdo --help    # справка, exit 0
./bin/letsdo           # usage и список агентов, exit 1
```

Корень проекта (где лежит `agents/`) — `LETSDO_ROOT`, по умолчанию текущая
папка. Дополнительные флаги pi — `LETSDO_PI_FLAGS` (или `AGENT_PI_FLAGS` для
совместимости с `bin/agent`), команда pi — `LETSDO_PI_COMMAND` (по умолчанию
`pi`, переопределяется в тестах).

Подключение как библиотеки:

```ruby
require "letsdo"        # module Letsdo, Letsdo::VERSION
```

## Структура кода

ООП-структура джема:

```
letsdo/
  bin/letsdo            # входная точка: тонкая обёртка над Letsdo::CLI
  lib/letsdo.rb         # module Letsdo, require всех компонентов
  lib/letsdo/errors.rb # Letsdo::Errors: иерархия ошибок
  lib/letsdo/prompt_store.rb  # Letsdo::PromptStore: промпты agents/*.md
  lib/letsdo/output_streamer.rb # Letsdo::OutputStreamer: куда печатать вывод
  lib/letsdo/pi_runner.rb     # Letsdo::PiRunner: запуск pi --mode json
  lib/letsdo/agent.rb         # Letsdo::Agent: один прогон агента
  lib/letsdo/loop.rb          # Letsdo::Loop: цикл оркестратора
  lib/letsdo/cli.rb           # Letsdo::CLI: аргументы, usage, код выхода
  test/                 # тесты Minitest (test/*_test.rb, fixtures/fake_pi)
  letsdo.gemspec        # name=letsdo, executables=["bin/letsdo"]
  Gemfile               # gemspec
  Rakefile              # rake test
  README.md
  LICENSE               # MIT
```

Ответственность классов:

- **Letsdo::Errors** — иерархия ошибок пакета: `Letsdo::Error` (базовая),
  `Letsdo::UnknownAgentError` (агента нет в `agents/`, несёт `.name`).
- **Letsdo::PromptStore** — доступ к промптам `agents/<имя>.md` в корне
  проекта: `list` (отсортированные имена), `read(name)` (содержимое или
  `UnknownAgentError`). Новый агент = новый файл, код менять не нужно.
- **Letsdo::OutputStreamer** — направляет вывод pi по двум потокам: текст
  ответа (text_delta) — в stdout, служебные строки инструментов — в stderr.
  Каждая строка-действие пишется с единым префиксом времени `HH:MM:SS`
  (запуск `⚙ имя: параметры`, завершение `✓/✖ имя: … (Xs)`), результат —
  блоком с отступом, большой вывод обрезается с заметкой-сводкой,
  результаты-ошибки помечаются (`✖ Ошибка: ...`); `finish` гарантирует
  финальный перевод строки. Длительность действия видна по разнице
  префиксов времени запуска и завершения.
- **Letsdo::PiRunner** — запускает `pi --mode json <флаги> <промпт>`, читает
  построчный поток событий, отдаёт стримеру `text_delta` (текст агента),
  заголовки и результаты инструментов (`tool_execution_start`/`_end`),
  игнорирует не-JSON и посторонние события, пробрасывает код выхода pi
  (включая 128+сигнал). Команда pi переопределяема (`command:`) — для тестов.
- **Letsdo::Agent** — один прогон агента: читает промпт из `agents/` через
  `PromptStore` и запускает `PiRunner`. Возвращает код выхода pi; для
  неизвестного имени бросает `UnknownAgentError`. Это логика одного прогона
  старого `bin/agent`, перенесённая в джем.
- **Letsdo::Loop** — цикл оркестратора: пока провайдер отдаёт открытые
  задачи — запускает агента (один прогон = одна задача); задач нет — ждёт
  и проверяет снова; `nil` от провайдера = бэклог не читается, агента не
  запускаем. Остановка — только снаружи через `#stop` (например, обработчиком
  SIGINT/SIGTERM, как в `bin/agent-loop`). Провайдер и раннер инжектируются —
  так цикл тестируется без реального бэклога и pi.
- **Letsdo::CLI** — разбор аргументов и запуск: usage и список агентов
  при отсутствии аргумента (exit 1), `--version`/`--help` (exit 0),
  неизвестная опция (exit 1), неизвестный агент — сообщение + список (exit 1);
  известный агент — прогон через `Letsdo::Agent`, код выхода pi.

## Разработка

Тесты на встроенном в Ruby Minitest (простой синтаксис `assert`/`refute`,
без внешних DSL и мок-фреймворков). Покрыты: чтение промптов `agents/`,
известный/неизвестный агент, сборка вывода из `text_delta`, заголовки и
результаты инструментов (включая ошибки и обрезку большого вывода),
префиксы времени `HH:MM:SS` у строк-действий, проброс
кода выхода, цикл оркестратора, CLI. Фейковый pi — `test/fixtures/fake_pi` —
эмулирует поток событий `pi --mode json` для детерминированных тестов
(сценарии `FAKE_PI_SCENARIO=default|error|big|stub`).

Запуск тестов без внешних гемов:

```sh
rake test                 # все тесты
ruby -Itest -Ilib test/prompt_store_test.rb   # один файл
```

Сборка джема:

```sh
gem build letsdo.gemspec
```

## Лицензия

MIT — см. [LICENSE](LICENSE).