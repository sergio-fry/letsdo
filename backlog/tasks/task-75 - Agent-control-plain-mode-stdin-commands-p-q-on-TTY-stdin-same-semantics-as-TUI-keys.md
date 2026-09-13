---
id: TASK-75
title: 'Plain mode: wire the p/q control reader into the CLI + PTY test + docs'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 08:26'
updated_date: '2026-09-13 14:15'
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
- [x] #1 Plain mode with TTY stdin: a PTY subprocess test shows `p` freezes a running pi (child in stopped state), a second `p` resumes, and `q` stops cleanly (pi terminated + "letsdo: stopped" + exit 0)
- [x] #2 `p`/`q` semantics are identical to the TUI keys: `q` == stop signal (Letsdo::Stopped unwind, exit 0); `p` == PauseGate toggle + runner pause/resume (no-op when nothing runs)
- [x] #3 Plain output stays byte-identical: no TUI escape codes, no echo from the control reader; existing plain-mode cli/output tests unchanged and green
- [x] #4 Non-TTY stdin (pipe/devnull/CI): no control reader started; SIGINT/SIGTERM still stop cleanly; documented in README
- [x] #5 README documents plain-mode control: p/q on TTY stdin, signal-only when stdin is not a TTY; texts English (TASK-35)
- [x] #6 Tests: PTY subprocess, non-TTY no-reader (pipe); rake test 0 failures; rubocop 0 offenses
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Wire the reader into run_plain (builder_metrics.rb): build the agent explicitly, create a shared Control::PauseGate, start Control::Reader(input: @stdin, pause_gate: gate, runner: -> { agent.backend }), pass agent+pause_gate into agent_loop. Reader.start is a no-op for non-TTY stdin, so stop stays signal-only.
2. Keep plain output untouched: the reader writes nothing; no raw mode, no escape codes.
3. PTY subprocess test (new test/plain_control_test.rb): PTY on stdin only, stdout/stderr pipes -> plain mode with TTY stdin. Assert p SIGSTOPs the running pi (State: T), second p resumes, q terminates pi + 'letsdo: stopped' + exit 0.
4. Unit test that a pipe stdin is never read (bytes intact, loop runs normally) = no reader on non-TTY.
5. Docs: README + docs/usage.md plain-mode control (p/q on TTY stdin, signal-only when stdin is not a TTY).
6. Verify: rake test 0 failures; rubocop 0 offenses.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Wiring: run_plain now builds the agent explicitly, shares a Control::PauseGate, and starts Control::Reader(input: @stdin, pause_gate:, runner: -> { agent.backend }); the reader is stopped in the ensure. Reader#stop added (kills the background thread) so no reader outlives the run. terminal_input? now also requires a public #gets, so a TTY-ish stream that is not line-readable (the TUI FakeTtyIn used by an existing plain-mode CLI test) never starts a reader.

Validation: new test/plain_control_test.rb spawns bin/letsdo with a PTY on stdin only (stdout/stderr pipes -> plain mode) and asserts: first 'p' puts the pi child into State: T (SIGSTOP), second 'p' resumes (SIGCONT), 'q' exits 0, stderr has 'letsdo: stopped', pi is gone, stdout has no escape codes. New test in cli_builder_test proves a pipe stdin is never read ("q\n" stays unread, loop runs to normal end). control_reader_test covers stop/never-started and the non-gets TTY gate.

Evidence: rake test -> 384 runs, 1128 assertions, 0 failures, 0 errors. rubocop --no-server lib bin test -> 80 files, 0 offenses. Docs: README feature bullet; docs/usage.md plain-mode p/q subsection + loop-behaviour mentions; CHANGELOG Unreleased entry.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Wired the TASK-94 stdin control reader into plain mode: run_plain builds the agent, shares a Control::PauseGate and starts Control::Reader with runner access to the live backend, stopping it in the ensure. p now pauses/resumes exactly like the TUI (gate + SIGSTOP/SIGCONT, no-op between runs) and q unwinds via Letsdo::Stopped to the same clean exit 0. Non-TTY stdin (pipe//dev/null/CI) starts no reader, so stop stays SIGINT/SIGTERM/SIGHUP-only; output remains a byte-identical plain stream. Verified with a PTY subprocess test (stdin TTY only; freeze/resume/quit, 'letsdo: stopped', exit 0, no escape codes), a pipe-stdin no-reader test, and reader lifecycle/gating unit tests; rake test 384 runs 0 failures and rubocop 80 files 0 offenses. README, docs/usage.md and CHANGELOG updated.
<!-- SECTION:FINAL_SUMMARY:END -->
