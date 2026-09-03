---
id: TASK-3
title: Понятная ошибка при неизвестном агенте
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 15:03'
updated_date: '2026-09-03 15:24'
labels: []
dependencies:
  - TASK-2
type: enhancement
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Если .agents/<имя>.md не существует — это ошибка: человекочитаемое сообщение, ненулевой код возврата, pi не запускается.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ./bin/agent no-such-agent выводит в stderr сообщение вида «Неизвестный агент: no-such-agent»
- [x] #2 Код возврата скрипта не равен 0
- [x] #3 pi не запускается (нет обращения к модели)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. В bin/agent добавить проверку существования .agents/<имя>.md до вызова pi. 2. Сообщение об ошибке в stderr, exit != 0, pi не запускается. 3. Проверка: ./bin/agent no-such-agent.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Проверка существования .agents/<имя>.md идёт до вызова pi: сообщение «Неизвестный агент: <имя>» пишется в stderr (>&2), exit=1, pi не запускается. Проверено: ./bin/agent no-such-agent → сообщение в stderr, exit 1, мгновенный возврат без обращения к модели.
<!-- SECTION:FINAL_SUMMARY:END -->
