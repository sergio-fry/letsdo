---
id: TASK-9
title: 'Вывод действий агента: параметры и результаты инструментов'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 15:27'
updated_date: '2026-09-03 17:05'
labels: []
dependencies: []
type: enhancement
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Сейчас во время выполнения агента видны только пустые маркеры вызовов (⚙ bash, ⚙ read) без содержимого — непонятно, что происходит и на чём агент застрял. Нужно выводить вызовы инструментов нормально: имя инструмента, параметры/аргументы вызова (например, текст команды bash) и результат выполнения (stdout/stderr команды; при очень большом объёме — аккуратная обрезка/сводка). Ошибки инструментов помечать. Текст ответа агента выводится как раньше.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 При вызове инструмента в выводе видны имя инструмента и его параметры (например, текст выполняемой команды)
- [x] #2 Виден результат выполнения инструмента (вывод команды; при большом объёме — обрезанная сводка)
- [x] #3 Результаты-ошибки явно помечены как ошибки
- [x] #4 Пустые строки-заглушки не выводятся, вывод остаётся читаемым
- [x] #5 Вывод появляется по мере выполнения (стриминг не теряется)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Изучить поток событий pi --mode json (v0.84.4: toolcall_start/delta/end в message_update; tool_execution_start/update/end — на верхнем уровне; result.content — массив текстовых блоков; isError — признак ошибки). Понять текущее поведение: стример печатает только '⚙ имя' без содержимого.
2. OutputStreamer (lib/agent + letsdo/lib/letsdo, идентично): tool_start(name, args:) — '⚙ имя: параметры' одной строкой (для bash — команда, для read/write/edit — путь, grep — pattern, прочее — краткий JSON; длинное — обрезка); tool_result(text, error:) — строки результата с отступом, обрезка по лимитам строк/символов с заметкой '… [вывод обрезан: N строк, M символов]', ошибки с префиксом '✖ Ошибка:'; пустые строки-заглушки не выводятся.
3. PiRunner (lib/agent + letsdo/lib/letsdo, идентично): toolcall_start — запомнить id→имя (фолбэк для pi без tool_execution_*); tool_execution_start — tool_start(имя, args) (имя+параметры появляются при старте выполнения); tool_execution_end — tool_result(текст из result.content, error: isError); агент_end/конец чтения — долить '⚙ имя' для вызовов без execution-событий. Текст агента (text_delta) — как раньше, по мере генерации (стриминг).
4. Тесты letsdo (Minitest): расширить fixtures/fake_pi реалистичной последовательностью (toolcall → execution → результат; сценарии error/big через FAKE_PI_SCENARIO); обновить pi_runner_test (заголовок с параметрами, результат, ошибка) и output_streamer_test (форматирование, обрезка, отсутствие пустых строк).
5. Проверка: rake test в letsdo/, ruby -c для bin/agent + lib/*, смоук-тест ./bin/agent developer с фейковым pi на PATH (виден заголовок с командой, результат, ошибка; stdout — только текст агента).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Проверка (объективные доказательства): (1) реальный прогон ./bin/agent developer с настоящим pi: в stderr видно '⚙ bash: cd ... && git status && echo ===LOG=== ...', '⚙ read: <путь>', '⚙ bash: cd ... && rake test ...' — имя+параметры; результаты команд печатаются с отступом; (2) обрезка: сценарий big (300 строк) — первые 100 строк + '… [вывод обрезан: 300 строк, 4200 символов]'; (3) ошибки: реальный вызов показал '✖ Ошибка: ruby: no Ruby script found in input (LoadError)'; сценарий error — '✖ Ошибка: ls: cannot access ...'; (4) пустых строк-заглушек нет (заголовок одной строкой, stub-сценарий печатает только '⚙ bash'); (5) стриминг: text_delta по-прежнему печатается немедленно с flush, заголовки — при старте выполнения, результаты — при завершении; exit code pi пробрасывается (exit=0; тест FAKE_PI_EXIT=7). rake test: 56 runs, 136 assertions, 0 failures. ruby -c: все файлы OK. Формат событий сверен с реальным pi 0.84.4 (--mode json): toolcall_start (id/toolName на верхнем уровне), tool_execution_start (args), tool_execution_end (result.content, isError).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @developer
created: 2026-09-03 16:53
---
Беру задачу в работу
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Вывод действий агента стал информативным: вместо пустых маркеров '⚙ bash' теперь показываются имя инструмента и параметры (для bash — текст команды, для read/write/edit — путь и диапазон, прочее — краткий JSON), результат с отступом (при большом объёме — аккуратная обрезка до 100 строк/4000 символов с заметкой '… [вывод обрезан: N строк, M символов]'), результаты-ошибки помечаются '✖ Ошибка:'. Изменены OutputStreamer + PiRunner в обоих клонах логики (lib/agent для bin/agent и letsdo/lib/letsdo для джема); PiRunner перешёл с toolcall_start на tool_execution_start/end (фолбэк '⚙ имя' при отсутствии событий выполнения). Текст агента по-прежнему стримится в stdout по мере генерации, служебное — в stderr. Проверено: rake test 56 runs / 136 assertions / 0 failures; реальный прогон ./bin/agent developer с настоящим pi подтвердил все 5 AC (имя+параметры, результат, обрезка, пометка ошибок, стриминг); exit code пробрасывается; README джема и комментарии обновлены.
<!-- SECTION:FINAL_SUMMARY:END -->
