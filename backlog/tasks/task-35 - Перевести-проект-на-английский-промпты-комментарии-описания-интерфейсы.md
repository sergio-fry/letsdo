---
id: TASK-35
title: 'Перевести проект на английский: промпты, комментарии, описания, интерфейсы'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 20:25'
updated_date: '2026-09-03 20:30'
labels: []
dependencies: []
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
В проекте должен использоваться только английский язык: все промпты агентов (agents/*.md), все комментарии в коде (lib/, bin/, test/), все описания (README.md, letsdo.gemspec), все пользовательские тексты интерфейсов (usage CLI, список агентов, сообщения об ошибках) — на английском. Поведение и логика не меняются: это перевод строк, а не переработка кода. После перевода промпта agents/developer.md агенты работают на английском (включая будущие записи в бэклоге). Исторические записи задач в backlog/ (закрытые и текущие) не переводим: это протокол прошлых решений; новые записи ведутся на английском.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Промпты agents/*.md полностью на английском; роль, правила, структура и смысл сохранены
- [x] #2 Комментарии во всех файлах lib/, bin/, test/ и README.md, letsdo.gemspec — на английском; grep по кириллице в них не находит совпадений
- [x] #3 Пользовательский интерфейс CLI на английском: usage, 'Available agents:', сообщение о неизвестном агенте ('Unknown agent: <name>'), --version/--help
- [x] #4 rake test зелёный (0 failures), логика и тесты не переписываются
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Translate agents/developer.md to English (role, rules, structure preserved).
2. Translate all comments and user-facing strings in lib/ (usage, 'Available agents:', 'Unknown agent: <name>', unknown option, tool verdicts, truncation notes) and bin/letsdo.
3. Translate test/ files and fixtures (comments + string literals) and fake_pi scenarios.
4. Translate README.md and letsdo.gemspec (summary/description).
5. Rake test stays green (0 failures); grep for Cyrillic in lib/, bin/, test/, README.md, letsdo.gemspec, agents/ finds nothing (backlog history untouched).
6. Finalize TASK-35 and commit, including the backlog folder.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: rake test -> 61 runs, 0 failures, 0 errors, 0 skips. grep -rlP '[\x{0400}-\x{04FF}]' over lib/ bin/ test/ agents/ README.md letsdo.gemspec AGENTS.md Rakefile Gemfile -> no matches (backlog history untouched). CLI checks: --help prints 'Usage: letsdo <agent_name>' + 'Available agents:' (exit 0); no args -> usage exit 1; unknown agent -> 'Unknown agent: nosuchagent' exit 1; --version -> 0.1.0 exit 0. Service streams translated: tool verdicts done/error, '✖ Error: ', '[output truncated: N lines, M characters]', plural helper simplified to English singular/plural (logic unchanged elsewhere). Fake_pi deltas now 'Hello, world!'. agents/looptest.md was already deleted (newagents cleanup); left as is.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Translated the whole project to English (behavior unchanged). Changed: agents/developer.md (role/rules/structure preserved), all comments in lib/ + bin/letsdo + tests, CLI user-facing strings (USAGE -> 'Usage: letsdo <agent_name>', 'Available agents:', 'Unknown agent: <name>', 'letsdo: unknown option: X'), service streams (tool verdicts done/error, '✖ Error: ', '[output truncated: N lines, M characters]'; plural helper simplified to English singular/plural), README.md, letsdo.gemspec summary/description, and test string literals incl. fake_pi scenarios ('Hello, world!'). Backlog history untouched. Verified: rake test -> 61 runs, 0 failures, 0 errors; grep for Cyrillic in lib/ bin/ test/ agents/ README.md letsdo.gemspec AGENTS.md Rakefile Gemfile -> 0 matches; CLI manual checks --help/--version/no-args/unknown-agent with exit codes 0/0/1/1.
<!-- SECTION:FINAL_SUMMARY:END -->
