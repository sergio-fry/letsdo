---
id: TASK-1
title: Промпт агента-разработчика в .agents/developer.md
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 15:03'
updated_date: '2026-09-03 15:24'
labels: []
dependencies: []
type: docs
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Создать файл .agents/developer.md — промпт (описание роли) агента-разработчика. Он считывается скриптом bin/agent и передаётся в pi как промпт. Роль: разработчик проекта News Tracker; правила работы с бэклогом (backlog CLI, AGENTS.md); язык общения; тон и принципы.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 .agents/developer.md существует в корне проекта
- [x] #2 Содержит роль и инструкции для агента-разработчика: контекст проекта, правила работы с бэклогом, стиль
- [x] #3 Промпт самодостаточен — по нему агент может начинать работу без дополнительных пояснений
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Описать роль и контекст агента-разработчика: проект News Tracker, работа через backlog CLI по протоколу AGENTS.md. 2. Зафиксировать правила работы: только backlog CLI для изменений бэклога; чтение гайдов (task-creation/execution/finalization) перед действиями; план и прогресс фиксируются в задаче. 3. Стиль: русский, кратко, с путями файлов; при нехватке данных — спрашивать, не додумывать.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Создан .agents/developer.md (роль агента-разработчика: контекст проекта News Tracker, правила работы с бэклогом через backlog CLI по AGENTS.md, стиль — русский, кратко, пути файлов, спрашивать при нехватке данных). Самодостаточен: ссылается на AGENTS.md/gаidы, по которым агент начинает работу. Проверено: файл существует, содержимое покрывает роль/правила/стиль.
<!-- SECTION:FINAL_SUMMARY:END -->
