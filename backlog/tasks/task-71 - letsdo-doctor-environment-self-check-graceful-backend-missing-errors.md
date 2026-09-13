---
id: TASK-71
title: 'letsdo doctor: environment self-check command'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:14'
updated_date: '2026-09-13 13:28'
labels: []
dependencies:
  - TASK-53
priority: medium
type: enhancement
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A newcomer needs one command that reports exactly what is broken in their environment and how to fix it. Today a missing `pi` on PATH raises a full Ruby backtrace, and a missing or empty `backlog/` makes the loop retry forever with no reason and no hint. Add `letsdo doctor` — an environment self-check that prints one line per check with a status tag and an actionable hint for every failure/warning, and exits 0 when nothing FAILs, 1 otherwise.

Note: the backend-missing case is already handled — `PiRunner` raises `Letsdo::BackendUnavailableError` and the CLI prints a clear message and exits 2 (no backtrace). This task adds only the `doctor` command; pointing the loop's "backlog unavailable" message at `letsdo doctor` is tracked separately.

Checks (one line each):
- ruby version >= 3.3 (RUBY_VERSION) — OK / WARN
- pi command on PATH (LETSDO_PI_COMMAND, default `pi`) — OK / FAIL
- backlog command on PATH (LETSDO_BACKLOG_COMMAND, default `backlog`) — OK / FAIL
- project root (LETSDO_ROOT, default pwd) has `backlog/` with `tasks/` — OK / FAIL
- AGENTS.md present at root — OK / WARN
- agents/ present and non-empty — OK / WARN (hint: `letsdo <name> --init`)
- stdout is a TTY — INFO (TUI vs plain mode)

All env values come from `Letsdo::Config` (no new direct ENV reads). `doctor` becomes a reserved agent name (documented in README + bin/letsdo header); `--version`/`--help` keep priority; unknown options still exit 1.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `letsdo doctor` prints one line per check with a status tag ([ OK ] / [WARN] / [FAIL] / [INFO]) and an actionable hint for every FAIL and WARN; exits 0 when there is no FAIL line, 1 otherwise
- [ ] #2 Checks cover at least: ruby version vs >= 3.3, pi on PATH (LETSDO_PI_COMMAND override honored), backlog on PATH (LETSDO_BACKLOG_COMMAND override honored), backlog/ with tasks/ under LETSDO_ROOT (default pwd), AGENTS.md (WARN), agents/ non-empty (WARN with `--init` hint), stdout TTY (INFO)
- [ ] #3 All env values come from Letsdo::Config: no new direct ENV reads in the new code
- [ ] #4 `--version`/`--help` keep priority and unknown options still exit 1; an agent named `doctor` is reserved (README + bin/letsdo header) and cannot be run by name
- [ ] #5 Tests: Minitest with fake pi/backlog via env and a temp project root, covering everything-present / pi missing / backlog missing / no backlog dir / no AGENTS.md / no agents / non-TTY stdout. rake test 0 failures; rubocop 0 offenses; all texts English (TASK-35)
<!-- AC:END -->
