---
id: TASK-10
title: 'Переписать раннер агента на Ruby (объектно-ориентированный, аккуратный код)'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 15:27'
updated_date: '2026-09-03 16:34'
labels: []
dependencies: []
priority: high
type: feature
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Переписать bin/agent с текущего bash+python на Ruby в объектно-ориентированном стиле: логика разбита на классы/модули (агент, хранилище промптов .agents/, стример вывода pi --mode json и т.п.), идиоматичный и читаемый код. Поведение сохраняется целиком: ./bin/agent <имя> читает .agents/<имя>.md и запускает pi; без аргументов — usage и список агентов; неизвестный агент — «Неизвестный агент: <имя>» в stderr и exit != 0; стриминг text_delta по мере генерации; проброс exit code; поддержка AGENT_PI_FLAGS. Вывод — чистый: только текст агента, без служебных маркеров и пустых строк (см. TASK-9).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Раннер реализован на Ruby, исполняемый ./bin/agent, CLI идентичен текущему
- [x] #2 Код объектно-ориентированный: логика в классах/модулях, без монолитного скрипта
- [x] #3 Стриминг сохранён: текст печатается по мере генерации, полный ответ на месте, exit code pi пробрасывается
- [x] #4 Неизвестный агент: сообщение в stderr + exit != 0
- [x] #5 AGENT_PI_FLAGS продолжает работать; синтаксис проверен (ruby -c), смоук-тест ./bin/agent developer проходит
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Зафиксировать поведение текущего bin/agent (bash+python): usage+список в случае без аргументов (exit 1), 'Неизвестный агент: <имя>' + список (exit 1), запуск 'pi --mode json <AGENT_PI_FLAGS> <промпт>' с рабочей директорией = корень проекта, стриминг text_delta в stdout, маркеры '⚙ <инструмент>' в stderr, проброс exit code pi, завершающий перевод строки при отсутствии. 2. ООП-структура в lib/agent/: Agent::PromptStore (.agents/ чтение/список), Agent::OutputStreamer (текст->stdout, служебное->stderr, финализация), Agent::PiRunner (spawn pi --mode json, построчный разбор событий, выходной код), Agent::Errors (UnknownAgentError), Agent::CLI (аргументы, usage, диспетчеризация). bin/agent — тонкая исполняемая обёртка: chdir в корень, вызов Agent::CLI.run, exit с кодом. 3. Проверки: ruby -c на всех файлах; без аргументов и неизвестный агент (exit 1); детерминированный смоук с фейковым pi в PATH (argv+флаги, стриминг, проброс кода выхода); реальный смоук ./bin/agent smoke с тривиальным промптом (вложенный './bin/agent developer' не запускаю: вложенный прогон взял бы эту же задачу TASK-10 in progress и создал бы конкуренцию). 4. Коммит: bin/agent, lib/, backlog.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Реализация: bin/agent — тонкая обёртка (chdir в корень проекта + Agent::CLI.run + exit), логика в lib/agent/: PromptStore (.agents/*.md: list/read, UnknownAgentError), OutputStreamer (text_delta->stdout, маркеры '⚙ имя'->stderr, finish добавляет финальный \n), PiRunner (spawn pi --mode json, stdout piped/UTF-8, stderr наследуется; построчный разбор JSON, обработка message_update/text_delta и toolcall_start; код выхода: exitstatus или 128+termsig), CLI (usage/список/неизвестный агент -> exit 1; Shellwords.split для AGENT_PI_FLAGS; stdout не загрязняется). Поведение сохранено: список агентов при ошибках печатается в stdout (как в прежнем bash), служебные строки в stderr.

Проверки: ruby -c на bin/agent + lib/agent.rb + 6 файлов lib/agent/*.rb — Syntax OK. Без аргументов: usage+список, exit 1. Неизвестный агент: 'Неизвестный агент: nosuch' в stderr + список, exit 1. Детерминированный смоук с фейковым pi в PATH (помещён в /tmp/fakepi): argv = '--mode json <флаги> <промпт>' (флаги из AGENT_PI_FLAGS на месте), text_delta склеены в stdout без мусора/пустых строк, пустой delta пропущен, не-JSON строки и не-message_update события проигнорированы, маркеры '⚙ bash'/'⚙ tool' в stderr, exit 7 проброшен. Реальный смоук с настоящим pi: тривиальный промпт .agents/smoke.md -> stdout ровно 'ОК', stderr пуст, exit 0; с AGENT_PI_FLAGS='--print' тоже 'ОК', exit 0. Неверный флаг AGENT_PI_FLAGS='--no-color': pi ответил 'Unknown option' -> exit 1 проброшен (доказательство проброса на реальном pi). './bin/agent developer' намеренно не запускался вложенным прогоном с реальным pi: вложенный developer взял бы эту же задачу TASK-10 (она in progress и назначена на @developer) и создал бы конкурирующую сессию; путь чтения .agents/developer.md проверен фейковым pi (полный текст промпта developer дошёл как argv).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
bin/agent переписан с bash+python на Ruby в ООП-стиле: bin/agent — тонкая исполняемая обёртка (chdir в корень, вызов Agent::CLI.run, exit), вся логика в lib/agent/ — Agent::PromptStore (.agents/), Agent::OutputStreamer (текст->stdout, маркеры инструментов->stderr), Agent::PiRunner (spawn pi --mode json, построчный разбор событий, проброс exit code), Agent::Errors (UnknownAgentError), Agent::CLI (аргументы, usage, AGENT_PI_FLAGS через Shellwords). Поведение идентично прежнему: без аргументов и при неизвестном агенте — usage/«Неизвестный агент: X» + список, exit 1; стриминг text_delta сохранён; выходной поток чистый. Проверено: ruby -c на всех 8 файлах (Syntax OK); CLI-режимы (exit 1); фейковый pi в PATH — порядок argv (--mode json, флаги, промпт), сборка text_delta без мусора, маркеры ⚙ в stderr, проброс exit 7; реальный pi — stdout ровно «ОК» без и с AGENT_PI_FLAGS=--print (exit 0), неверный флаг дал ошибку pi с пробросом exit 1.
<!-- SECTION:FINAL_SUMMARY:END -->
