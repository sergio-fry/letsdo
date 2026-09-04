---
id: TASK-58
title: >-
  Provider selection: LETSDO_PROVIDER knob + registry in Letsdo::CLI::Builder
  (default backlog)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:37'
labels: []
dependencies:
  - TASK-42
  - TASK-53
  - TASK-54
  - TASK-56
references:
  - TASK-51
type: enhancement
ordinal: 47000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Second half of the TASK-51 spike (task provider adapter seam). After TASK-56 lands, Letsdo::Providers::Backlog exists behind the normalized TaskProvider contract; this task makes trackers selectable: LETSDO_PROVIDER env knob (default 'backlog') read at the single config point (Letsdo::Config from TASK-53), and a provider registry owned by the wiring layer (Letsdo::CLI::Builder from TASK-54). Letsdo::Loop and Letsdo::AgentLoop keep their callable task_provider contract unchanged — the selection happens only in the wiring, so no protocol change. Behavior identical today: without LETSDO_PROVIDER everything runs exactly as now (backlog default, same handle/command/cwd/env context).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Letsdo::Config reads LETSDO_PROVIDER with default 'backlog' (empty/invalid value -> default), documented in its env list; README/cli docstrings list the new variable
- [ ] #2 Letsdo::CLI::Builder owns a provider registry mapping provider names to factories (PROVIDERS = { 'backlog' => ... }); both wiring paths (plain and TUI) build the provider through it with the same handle/command/cwd/env context as today
- [ ] #3 Unknown LETSDO_PROVIDER value fails fast: 'letsdo: unknown task provider: <name>' on stderr and exit code 1 — no silent fallback
- [ ] #4 Injectable for tests: Builder accepts a provider factory/registry override; existing cli_test fake_backlog tests pass unchanged (they set LETSDO_BACKLOG_COMMAND and no LETSDO_PROVIDER -> backlog default path)
- [ ] #5 Letsdo::Loop and Letsdo::AgentLoop require no protocol change: callable task_provider contract untouched, only the task_label delta from TASK-56; a factory can be switched in a unit test and the loop behaves identically
- [ ] #6 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35)
<!-- AC:END -->
