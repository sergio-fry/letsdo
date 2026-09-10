---
id: TASK-58
title: >-
  Provider selection: LETSDO_PROVIDER knob + registry in Letsdo::CLI::Builder
  (default backlog)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 07:37'
updated_date: '2026-09-10 17:22'
labels: []
dependencies:
  - TASK-42
  - TASK-53
  - TASK-54
  - TASK-56
references:
  - TASK-51
priority: medium
type: enhancement
ordinal: 47000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Second half of the TASK-51 spike (task provider adapter seam). After TASK-56 lands, Letsdo::Providers::Backlog exists behind the normalized TaskProvider contract; this task makes trackers selectable: LETSDO_PROVIDER env knob (default 'backlog') read at the single config point (Letsdo::Config from TASK-53), and a provider registry owned by the wiring layer (Letsdo::CLI::Builder from TASK-54). Letsdo::Loop and Letsdo::AgentLoop keep their callable task_provider contract unchanged — the selection happens only in the wiring, so no protocol change. Behavior identical today: without LETSDO_PROVIDER everything runs exactly as now (backlog default, same handle/command/cwd/env context).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Letsdo::Config reads LETSDO_PROVIDER with default 'backlog' (empty/invalid value -> default), documented in its env list; README/cli docstrings list the new variable
- [x] #2 Letsdo::CLI::Builder owns a provider registry mapping provider names to factories (PROVIDERS = { 'backlog' => ... }); both wiring paths (plain and TUI) build the provider through it with the same handle/command/cwd/env context as today
- [x] #3 Unknown LETSDO_PROVIDER value fails fast: 'letsdo: unknown task provider: <name>' on stderr and exit code 1 — no silent fallback
- [x] #4 Injectable for tests: Builder accepts a provider factory/registry override; existing cli_test fake_backlog tests pass unchanged (they set LETSDO_BACKLOG_COMMAND and no LETSDO_PROVIDER -> backlog default path)
- [x] #5 Letsdo::Loop and Letsdo::AgentLoop require no protocol change: callable task_provider contract untouched, only the task_label delta from TASK-56; a factory can be switched in a unit test and the loop behaves identically
- [x] #6 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add LETSDO_PROVIDER selection to Letsdo::Config with a backlog default and focused config tests; document the variable in README, CLI docstrings, and config docs.
2. Add a provider registry to Letsdo::CLI::Builder and route plain/TUI provider construction through it while preserving current handle, command, cwd, and env wiring.
3. Add fail-fast handling for unknown providers and injectable provider-factory/registry overrides for tests.
4. Add registry, default-path, unknown-provider, and factory-switch tests; verify Loop and AgentLoop contracts are unchanged.
5. Run focused and full tests plus RuboCop over lib/, bin/, and test/, record evidence in the task, finalize, and commit all changes with the task ID.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented provider selection via LETSDO_PROVIDER env var with default 'backlog'. Added provider registry to CLI::Builder, fail-fast handling for unknown providers, and test injectability. Verified all tests pass (257 runs, 0 failures) and rubocop reports 0 offenses.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added LETSDO_PROVIDER env knob (default 'backlog') to Letsdo::Config; provider registry in CLI::Builder (PROVIDERS = { 'backlog' => ... }) with injectable override for tests; unknown provider fails fast ('letsdo: unknown task provider: <name>', exit 1); no protocol change to Loop/AgentLoop. Verified: 257 runs/761 assertions all pass, rubocop 0 offenses over lib/ bin/ test/, all English texts.
<!-- SECTION:FINAL_SUMMARY:END -->
