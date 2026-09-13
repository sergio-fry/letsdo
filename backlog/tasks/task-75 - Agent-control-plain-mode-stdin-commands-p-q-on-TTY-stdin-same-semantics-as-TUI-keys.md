---
id: TASK-75
title: 'Plain mode: wire the p/q control reader into the CLI + PTY test + docs'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:26'
updated_date: '2026-09-13 13:29'
labels: []
dependencies:
  - TASK-94
  - TASK-74
priority: medium
type: enhancement
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Wire the control reader (TASK-94) into the CLI: when letsdo runs in plain mode (stdout not a TTY / TERM=dumb / CI) and stdin IS a terminal, start the reader and hand it the PauseGate and runner access so `p`/`q` behave exactly like the TUI keys (TASK-74). Output must stay byte-identical to today (no escape codes, no echo from the reader). When stdin is not a TTY the reader is not started — stop remains signal-only (SIGINT/SIGTERM). Add a PTY-based subprocess test and README docs.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Plain mode with TTY stdin: a PTY subprocess test shows `p` freezes a running pi (child in stopped state), a second `p` resumes, and `q` stops cleanly (pi terminated + "letsdo: stopped" + exit 0)
- [ ] #2 `p`/`q` semantics are identical to the TUI keys: `q` == stop signal (Letsdo::Stopped unwind, exit 0); `p` == PauseGate toggle + runner pause/resume (no-op when nothing runs)
- [ ] #3 Plain output stays byte-identical: no TUI escape codes, no echo from the control reader; existing plain-mode cli/output tests unchanged and green
- [ ] #4 Non-TTY stdin (pipe/devnull/CI): no control reader started; SIGINT/SIGTERM still stop cleanly; documented in README
- [ ] #5 README documents plain-mode control: p/q on TTY stdin, signal-only when stdin is not a TTY; texts English (TASK-35)
- [ ] #6 Tests: PTY subprocess, non-TTY no-reader (pipe); rake test 0 failures; rubocop 0 offenses
<!-- AC:END -->
