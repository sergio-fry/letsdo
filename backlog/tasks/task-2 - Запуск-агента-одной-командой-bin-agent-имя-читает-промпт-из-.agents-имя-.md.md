---
id: TASK-2
title: >-
  Запуск агента одной командой: bin/agent <имя> читает промпт из
  .agents/<имя>.md
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 15:03'
updated_date: '2026-09-03 15:24'
labels: []
dependencies: []
type: feature
ordinal: 2000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Сейчас промпт передаётся аргументом скрипту bin/agent-developer. Нужен единый раннер: ./bin/agent <имя_агента> читает промпт из .agents/<имя>.md и запускает pi (--print) с этим промптом, выводя ответ. Дополнительные файлы в .agents/ дают новых агентов без изменения скрипта. Старый bin/agent-developer удаляется.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ./bin/agent developer запускает pi с содержимым .agents/developer.md как промптом и печатает ответ
- [x] #2 Скрипт работает из любой директории (сам переходит в корень проекта)
- [x] #3 Новый агент = новый файл .agents/<имя>.md, изменение скрипта не требуется
- [x] #4 Старый bin/agent-developer удалён из репозитория
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Написать bin/agent: принимает <имя_агента>, переходит в корень проекта, читает .agents/<имя>.md как промпт и запускает pi --print с ним. 2. Удалить старый bin/agent-developer. 3. Смоук-тест: ./bin/agent developer отвечает промптом из .agents/developer.md.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Создан bin/agent: принимает <имя>, cd в корень проекта, читает .agents/<имя>.md и запускает pi --print с этим промптом (exec — проброс stdout и exit code). Старый bin/agent-developer удалён. Проверено: ./bin/agent developer отработал с промптом из .agents/developer.md (exit 0); из /tmp корректно найден корень и список агентов; временный .agents/tmp-agent.md появился в списке без изменения скрипта; bin/ содержит только agent.
<!-- SECTION:FINAL_SUMMARY:END -->
