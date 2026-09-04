---
id: TASK-75
title: >-
  Agent control: plain-mode stdin commands 'p'/'q' on TTY stdin (same semantics
  as TUI keys)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:26'
labels: []
dependencies:
  - TASK-74
priority: medium
type: enhancement
ordinal: 64000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Non-TUI control story designed in TASK-67 (comment: NON-TUI STORY + RECONCILIATION): when letsdo runs in plain line-stream mode (stdout not a TTY / TERM=dumb / CI) and stdin IS a terminal, a small control reader thread reads Enter-terminated commands: 'p' toggles pause (Control::PauseGate + PiRunner#pause/resume — identical semantics to the TUI 'p', TASK-74) and 'q' requests a clean stop (Thread.main.raise Letsdo::Stopped — identical to a stop signal: pi terminated, exit 0, plain output byte-identical). When stdin is NOT a TTY (pipes, /dev/null, CI) the reader is not started — stop remains signal-only (SIGINT/SIGTERM, existing), pause unavailable, documented. The reader thread mirrors the TUI input-thread pattern (Thread.main.raise is trapless and CRuby-4.0-safe). The control reader must exit quietly on EOF and must never steal stdin bytes when stdin is a pipe (TTY-gated).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Plain mode with TTY stdin: subprocess test (e.g. PTY) — sending 'p' freezes a running pi (child stopped state observed); second 'p' resumes; 'q' stops cleanly: pi terminated + 'letsdo: stopped' + exit 0.
- [ ] #2 'p'/'q' semantics identical to TUI keys: 'q' == stop signal (Letsdo::Stopped unwind, exit 0); 'p' == PauseGate toggle + runner pause/resume (no-op when nothing runs / group gone).
- [ ] #3 Plain output stays byte-identical to today: no TUI escape codes, no echo from the control reader (reader is inert wrt stdout/stderr); existing plain-mode cli/output tests unchanged and green.
- [ ] #4 Non-TTY stdin (pipe/devnull/CI): no control reader started; SIGINT/SIGTERM still stop cleanly (existing behavior); behavior documented in README.
- [ ] #5 EOF or reader error → reader exits quietly, loop keeps running (stop remains signal-only); no crash, no partial output corruption.
- [ ] #6 README documents plain-mode control: 'p'/'q' on TTY stdin, signal-only when stdin is not a TTY; UI/help texts in English (TASK-35).
- [ ] #7 Tests: TTY-stdin subprocess (PTY), non-TTY no-reader (pipe), reader EOF/quiet-exit; rake test 0 failures; rubocop 0 offenses.
- [ ] #8 Affected: new lib/letsdo/control.rb (stdin ControlReader), lib/letsdo/cli.rb (start reader in plain mode when stdin.tty?; pass PauseGate + runner access), tests, README.
<!-- AC:END -->
