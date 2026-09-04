---
id: TASK-49
title: 'Translate open tasks to English (TASK-37, TASK-40, TASK-45)'
status: To Do
assignee:
  - '@analyst'
created_date: '2026-09-04 07:07'
labels: []
dependencies:
  - TASK-48
type: chore
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Translate the currently open backlog tasks that still contain Russian into English, per the English-only task tracking rule (TASK-48). Scan (2026-09-04) shows exactly three open tasks with Cyrillic content: TASK-37 (RuboCop: дефолтные стили, исправление кода, проверка в CI), TASK-40 (Убрать вывод результатов тулов: только строки вызова инструментов со временем), TASK-45 (Пробуждение цикла по изменениям файлов бэклога вместо опроса каждые ~10 с (inotify/FSEvents)). All other open tasks (42/43/44/46/47) are already English.

Translate what exists in each task: title, description, acceptance criteria, notes/comments. Preserve technical meaning and specifics (task numbers, Ruby/RuboCop terms, inotify/FSEvents). Only 'backlog task edit' via the CLI — never direct edits to backlog/tasks/*.md (project rule: backlog files are CLI-only).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 TASK-37, TASK-40, TASK-45 fully translated to English: titles, descriptions, acceptance criteria, notes
- [ ] #2 Verified with a Cyrillic scan of backlog/tasks/*.md: zero open task files contain Cyrillic after the translation
- [ ] #3 All edits applied via backlog task edit CLI; no direct markdown file edits
- [ ] #4 Translation preserves exact technical meaning (no dropped details like task numbers, tool names, timing)
<!-- AC:END -->
