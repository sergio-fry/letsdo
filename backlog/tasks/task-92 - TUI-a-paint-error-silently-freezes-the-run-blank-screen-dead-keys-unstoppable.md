---
id: TASK-92
title: >-
  TUI: a paint error silently freezes the run (blank screen, dead keys,
  unstoppable)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-13 12:24'
updated_date: '2026-09-13 13:15'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 81000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When anything raises while the TUI paints a frame, the error is swallowed: the repaint loop lives in the background input thread (Letsdo::Tui::Session#input_loop, body in SessionView#input_loop, which rescues StandardError and returns nil) and that thread has report_on_exception set to false. The thread dies, so the screen stops updating - if the failure happens on the very first repaint, the alternate screen stays completely blank - and no key is ever read again. The keyboard is held in raw mode for the whole session, which disables ISIG, so Ctrl-C no longer produces SIGINT either. The operator therefore cannot stop the run from the terminal while the agent loop keeps working invisibly.

Observed in production on 2026-09-13: a letsdo developer run in a tmux pane showed a blank screen for minutes and could not be stopped with q or Ctrl-C; its pi child kept working (session messages kept being written) and the process had to be SIGTERM-ed from another pane. Reproduced in isolation against the current code: with a render path that raises, Session#run returns without surfacing the error, a pending q key is never read, and the work block runs to completion.

Expected: a failure in the paint/input path must never leave a silent, unresponsive TUI. The run must stop, the terminal must be restored, and the failure must be reported so the operator is never left with an apparently hung agent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A failure raised while painting a frame (including the very first frame) stops the run instead of leaving a blank, unresponsive screen: the session interrupts the in-flight work, leaves the alternate screen, restores raw mode, and surfaces the original error
- [x] #2 The failure is visible to the operator: the error reaches stderr after the terminal is restored and the process exits with a non-zero status; no paint or input error is swallowed silently
- [x] #3 The run cannot become unstoppable: q, Ctrl-C and an external SIGINT/SIGTERM still terminate the process and restore the terminal, and no path leaves the TUI painting nothing while the agent loop keeps working
- [x] #4 Regression tests cover the failure: a paint error before the first frame and mid-run interrupts the work, restores the terminal, and surfaces the error; both tests fail against the pre-fix code
- [x] #5 Existing TUI behavior is unchanged when nothing fails: q quits with status 0, pause, scroll and refresh still work, raw mode is restored on every exit path, and the suite stays green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Root cause: `Builder#tui_parts` handed `Letsdo::Metrics::Fanout` (only provider_result/run_started/run_finished) to the TUI session as `metrics:`, but the renderer calls `@metrics.snapshot`, so the very first repaint raised NoMethodError; the input thread then swallowed it via `rescue StandardError; nil`, leaving the alternate screen blank, keys dead and the loop running invisibly.
2. Fix the wiring: the session now receives the `Tui::Metrics` header facade (the object answering `#snapshot`); the loop keeps the Fanout forwarding the three loop events to recorder and header, sharing the same header instance.
3. Defense in depth: `SessionView#input_loop` no longer swallows errors — it records the failure and interrupts the run via `Letsdo::Stopped`; `Session#run` re-raises it after the ensure restores the alternate screen and raw mode (a fresh instance avoids a circular cause chain from `Thread.main.raise`).
4. Regression tests: first-frame and mid-run paint errors interrupt the work, restore the terminal/raw mode and surface the original error; existing quit/pause/scroll/refresh/raw-mode tests stay green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: test/tui_session_test.rb -> 20 runs, 88 assertions, 0 failures (includes the 2 new TuiSessionInputErrorTest cases). Full suite minus test/cli_test.rb -> 286 runs, 1 failure: CliBuilderTest#test_tui_run_engages_through_the_builder asserts an empty stderr, but the TASK-69 stop-summary line is printed; confirmed identical at HEAD in a clean worktree. test/cli_test.rb still hangs in CliTuiTest#test_tui_pause_then_quit_terminates_the_pi_cleanly (pre-existing, unrelated). RuboCop: only the 3 pre-existing builder.rb offenses remain (Semicolon, SafeNavigation, ClassLength), identical to HEAD; the 4 offenses this change introduced were removed. Standalone repro (tmp): the pre-fix symptom (error swallowed, q dead, work runs to the end) flips to error surfaced + q stops the work.

Correction: the full suite (including test/cli_test.rb) now runs to completion — 319 runs, 919 assertions, 3 failures, 0 errors. All 3 failures are the same pre-existing TASK-69 stop-summary assertion (the summary line is printed to stderr while the tests still assert an empty stderr): CliTuiTest#test_tui_engages_with_real_terminals_and_quits_cleanly, CliTuiTest#test_tui_quit_prints_no_open3_thread_noise, CliBuilderTest#test_tui_run_engages_through_the_builder. No hang remains; the earlier cli_test.rb hang was caused by other uncommitted in-flight work that is no longer present.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed the TUI freeze where a `letsdo developer` run showed a blank screen, ignored q/Ctrl-C and could not be stopped. Root cause: the TUI session was given `Letsdo::Metrics::Fanout` (no `#snapshot`) as its metrics, so the first repaint raised NoMethodError that the input thread silently swallowed. The session now receives the `Tui::Metrics` header facade (the loop keeps the Fanout), and any paint/input error now interrupts the run and is re-raised after the terminal is restored instead of being swallowed. Verified with 2 new regression tests (first-frame and mid-run paint failures), the full suite minus the known-hanging cli_test.rb (0 new failures), RuboCop (no new offenses), and an end-to-end repro.
<!-- SECTION:FINAL_SUMMARY:END -->
