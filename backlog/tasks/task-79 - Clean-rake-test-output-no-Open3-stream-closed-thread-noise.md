---
id: TASK-79
title: 'Clean rake test output: no Open3 "stream closed" thread noise'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 12:45'
updated_date: '2026-09-04 13:03'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 68000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Every `rake test` prints several Thread terminated with exception (report_on_exception is true) backtraces from Open3.capture3: IOError stream closed in another thread (open3.rb around the stdout/stderr reader threads). The suite can still finish with 0 failures; the noise is from Letsdo::BacklogTasks calling Open3.capture3 against test/fixtures/fake_backlog (and similar short-lived children). Progress output should stay the Minitest dots plus the usual summary — no Open3 thread dumps on a green or ordinary run. Real test failures and assertion messages stay visible.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A green `rake test` run prints no Open3/IOError "stream closed in another thread" thread dumps
- [x] #2 Minitest progress (dots) and the final run/assertion/failure summary remain
- [x] #3 Failed assertions and errors still print their messages and backtraces
- [x] #4 Existing tests stay green (0 failures, 0 errors)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Root cause: the TUI input thread and the signal handlers raise Letsdo::Stopped into the main thread (Thread.main.raise). When this lands while Open3.capture3 has an in-flight 'backlog' child, it interrupts out_reader.value; Open3's popen_run ensure then closes the stdout/stderr pipes while its reader threads are still blocked in IO#read — the threads die with 'stream closed in another thread' and report_on_exception dumps them to stderr. Happens in TUI quit tests (deterministic) and would happen in production on Ctrl-C/SIGTERM during a backlog call.
2. Fix in Letsdo::BacklogTasks: replace Open3.capture3 with a private capture helper (same [stdout, stderr, status] contract; same leading env-hash + chdir support) whose reader threads set report_on_exception=false and rescue IOError (the benign stop-path stream-close) returning nil — so interrupting the wait can never print thread dumps. The helper always closes pipe ends and reaps the child via Process.detach even if the wait was interrupted, keeping exit-status semantics and real-error visibility (non-IOError reader exceptions still re-raise through Thread#value).
3. Regression test in CliTuiTest: run the TUI 'q' scenario with  captured, assert no 'stream closed'/'terminated with exception' and the normal assertions still hold.
4. Verify: rake test output shows only Minitest dots + summary (no Open3 dumps); failed-assertion visibility verified by an intentional failing run; rubocop 1.77 defaults clean.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Root cause: TUI SessionKeys#quit and the signal handlers raise Letsdo::Stopped into the main thread (Thread.main.raise). When the raise lands while Open3.capture3 has an in-flight backlog CLI child, it interrupts out_reader.value; open3's popen_run ensure then closes the stdout/stderr pipes while its reader threads are still blocked in IO#read — each reader dies with 'stream closed in another thread' and report_on_exception dumps it to stderr. Deterministically reproduced in test_tui_engages_with_real_terminals_and_quits_cleanly and test_tui_pause_then_quit_terminates_the_pi_cleanly (4 dumps per cli_test run); also a latent production bug on Ctrl-C/SIGTERM during a backlog call.
Fix: new Letsdo::Capture (lib/letsdo/capture.rb) replaces Open3.capture3 in Letsdo::BacklogTasks. Reader threads set report_on_exception=false and rescue the benign IOError (nil), so closing pipes under a stop never dumps; cleanup always closes pipe ends and reaps via Process.detach even when the wait was interrupted; non-IOError reader exceptions still re-raise via Thread#value. Same [stdout, stderr, status] contract, leading env-hash and chdir: preserved.
Regression test: CliTuiTest#test_tui_quit_prints_no_open3_thread_noise captures the process  around the 'q' scenario and asserts no 'stream closed'/'terminated with exception'.
Validation: rake test multiple runs — 0 failures/0 errors, zero Open3 dumps (before: 8 matches), Minitest dots+summary intact (Ruby 4.0.2 and 3.4.4); intentional failing suite still prints Failure/Error messages+backtraces (AC 3 probe in /tmp); rubocop 1.77.0 defaults clean on lib/bin/test; gem build OK.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Replaced Open3.capture3 in Letsdo::BacklogTasks with a new interruption-safe Letsdo::Capture (lib/letsdo/capture.rb). Root cause: a stop (TUI quit / signal) raises Letsdo::Stopped into the main thread mid-capture3, so open3's ensure closes the pipes while its reader threads are still blocked in IO#read, and report_on_exception dumps 'stream closed in another thread' to stderr. Capture's reader threads stay silent on that benign IOError and cleanup always reaps the child, so stops can never print dumps or leave zombies, while real reader errors still re-raise. Added CliTuiTest#test_tui_quit_prints_no_open3_thread_noise capturing process stderr. Verified: rake test (Ruby 4.0.2 and 3.4.4) — 176 runs, 0 failures/0 errors, output is only the dots + summary (previously 8 Open3 dumps); an intentionally failing suite still prints Failure/Error messages and backtraces; rubocop 1.77.0 defaults: 46 files, 0 offenses; gem build OK.
<!-- SECTION:FINAL_SUMMARY:END -->
