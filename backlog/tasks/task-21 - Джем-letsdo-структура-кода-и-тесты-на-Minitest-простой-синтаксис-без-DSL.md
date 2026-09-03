---
id: TASK-21
title: 'Джем letsdo: структура кода и тесты на Minitest (простой синтаксис, без DSL)'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 16:20'
updated_date: '2026-09-03 16:52'
labels: []
dependencies:
  - TASK-20
priority: high
type: feature
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Спроектировать ООП-структуру кода letsdo: классы/модули (агенты, хранилище промптов .agents/, стример вывода pi --mode json, обработка ошибок, цикл) с прицелом на перенос логики bin/agent. Покрыть ключевые компоненты тестами на встроенном в Ruby Minitest: максимально простой синтаксис (minitest/autorun, assert/refute), без внешних DSL и мок-фреймворков. Запуск тестов без внешних гемов (rake test / ruby -Itest).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Структура кода описана (README или docs): классы и их ответственность
- [x] #2 Тесты на Minitest простым синтаксисом, без внешних DSL-гемов
- [x] #3 Покрыты минимум: чтение промптов .agents/, известный/неизвестный агент, сборка вывода из text_delta, проброс exit code
- [x] #4 Тесты проходят: 0 failures
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Структура джема letsdo/lib/letsdo/ (порт логики bin/agent под модуль Letsdo): Errors (Error, UnknownAgentError), PromptStore (.agents/), OutputStreamer (text_delta→stdout, служебное→stderr, finish), PiRunner (spawn pi --mode json, разбор событий, проброс exit code; command переопределяем для тестов), Agent (один прогон: имя→промпт→pi), Loop (оркестратор: открытые задачи→прогоны; пусто→ожидание; SIGINT/SIGTERM→стоп), CLI (usage, --version/--help, неизвестный агент, LETSDO_PI_FLAGS/AGENT_PI_FLAGS).
2. bin/letsdo — тонкая обёртка над Letsdo::CLI (root = LETSDO_ROOT или pwd), сохраняет контракт TASK-20 (+<имя> запускает агента).
3. Тесты Minitest в letsdo/test/ (minitest/autorun, assert/refute, без моков/DSL): prompt_store, output_streamer (сборка text_delta, пустые delta, tool_start, finish), pi_runner (фейковый pi-скрипт: сборка вывода из text_delta, игнор не-JSON/не message_update, проброс exit code, порядок argv), agent (известный/неизвестный), loop (прогоны по задачам, ожидание, остановка, отказ провайдера), cli (usage/список/неизвестный агент/exit code pi).
4. README: секция «Структура кода» (классы и ответственность) — AC#1; раздел разработки (rake test / ruby -Itest).
5. Проверка: rake test → 0 failures; ruby -c на файлах; gem build не ломается.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Реализована ООП-структура джема letsdo (порт логики bin/agent в модуль Letsdo): Errors (Error, UnknownAgentError с .name), PromptStore (.agents/: list/read), OutputStreamer (text_delta→stdout, tool_start→stderr, finish с финальным \n), PiRunner (spawn 'pi --mode json <флаги> <промпт>', построчный разбор JSON, игнор не-JSON/не message_update/пустых delta, проброс exit code: exitstatus или 128+termsig; command: переопределяем для тестов), Agent (один прогон: имя→промпт→pi, UnknownAgentError), Loop (оркестратор: провайдер задач + раннер инжектируются; nil=бэклог не читается→ретрай без запуска; stop() снаружи), CLI (usage/список, --version/-v, --help/-h, неизвестная опция, неизвестный агент; LETSDO_ROOT, LETSDO_PI_FLAGS/AGENT_PI_FLAGS, LETSDO_PI_COMMAND для тестов). bin/letsdo — тонкая обёртка над Letsdo::CLI; README обновлён секцией «Структура кода» (AC#1) и разработкой.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @developer
created: 2026-09-03 16:52
---
Проверка AC:
#1: README.md — секция «Структура кода»: 8 классов с ответственностью (Errors, PromptStore, OutputStreamer, PiRunner, Agent, Loop, CLI).
#2: тесты используют только minitest/autorun + assert/refute, без DSL и мок-фреймворков; фикстуры — tmpdir/StringIO/fake_pi (stdlib).
#3: чтение промптов — PromptStoreTest; известный/неизвестный агент — PromptStoreTest, AgentTest (raise), CliTest (exit 1 + сообщение + список); сборка text_delta — PiRunnerTest (Привет, мир!, игнор не-JSON/other/пустого delta), OutputStreamerTest; проброс exit code — PiRunnerTest (FAKE_PI_EXIT=7 → 7), AgentTest, CliTest.
#4: rake test и ruby -Itest -Ilib: 40 runs, 92 assertions, 0 failures, 0 errors, 0 skips.
Доп.: bin/letsdo e2e — --version (0.1.0), --help, usage+список, неизвестная опция; прогон агента через fake_pi: stdout 'Привет, мир!', stderr '⚙ bash', exit 5 проброшен; gem build OK.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Спроектирована и реализована ООП-структура джема letsdo (letsdo/lib/letsdo/): Letsdo::Errors (UnknownAgentError), Letsdo::PromptStore (.agents/), Letsdo::OutputStreamer, Letsdo::PiRunner (pi --mode json, разбор событий, проброс exit code), Letsdo::Agent (один прогон), Letsdo::Loop (цикл оркестратора с инжектируемыми провайдером/раннером), Letsdo::CLI. bin/letsdo — тонкая обёртка над Letsdo::CLI (сохранён контракт каркаса + запуск агентов). Тесты Minitest (простым синтаксисом, без внешних гемов/DSL/моков; fake_pi фикстура) покрывают: чтение .agents/, известный/неизвестный агент, сборку вывода из text_delta, проброс exit code, цикл, CLI. Проверено: rake test и ruby -Itest -Ilib → 40 runs, 92 assertions, 0 failures; e2e bin/letsdo (version/help/usage/неизвестная опция, прогон агента через fake pi: stdout текст, stderr ⚙ bash, exit 5 проброшен); gem build OK. README дополнен секцией «Структура кода».
<!-- SECTION:FINAL_SUMMARY:END -->
