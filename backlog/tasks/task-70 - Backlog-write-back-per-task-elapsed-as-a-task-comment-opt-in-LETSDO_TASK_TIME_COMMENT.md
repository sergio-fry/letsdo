---
id: TASK-70
title: >-
  Backlog write-back: per-task elapsed as a task comment (opt-in,
  LETSDO_TASK_TIME_COMMENT)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 08:10'
updated_date: '2026-09-13 13:59'
labels: []
dependencies:
  - TASK-69
priority: medium
type: enhancement
ordinal: 59000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement TASK-63 design C3 point 3: at session stop, persist per-task elapsed into the task record as a backlog comment. Opt-in via env LETSDO_TASK_TIME_COMMENT=1 (default off — no task-file mutations, no extra subprocesses). At stop, for each exit-0 run whose task id is ABSENT from a fresh final provider snapshot (re-query once; still-open tasks are skipped — 'completed' would be wrong), the CLI runs the configured backlog command (LETSDO_BACKLOG_COMMAND, cwd = root): backlog task edit <id> --comment 'letsdo: completed in 4m 12s' --comment-author @letsdo. Write failures are non-fatal (warn once per task; summary notes 'N comments not written'). The recorder stays provider-agnostic — write-back lives in CLI over recorder runs; batched at stop (all agent runs dead → no race with a run's closing edit; file-based backlog CLI has no locks). Affected components: lib/letsdo/cli.rb (stop-path hook, duration formatting shared with TASK-69 summary), tests, README. Consumes the run records from TASK-69's Letsdo::SessionRecorder.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 With LETSDO_TASK_TIME_COMMENT unset or not equal to 1, no task file is modified, no backlog subprocess runs, and behavior is identical to TASK-69 alone
- [x] #2 With LETSDO_TASK_TIME_COMMENT=1, at session stop each exit-0 run whose task is no longer open gets a comment recording the elapsed duration, authored as @letsdo; still-open tasks are skipped
- [x] #3 A missing/renamed task or a failing backlog command warns once per task on stderr, does not abort the stop path, the summary reports 'N comments not written', and the process exit code stays 0
- [x] #4 Tests verify flag-off (no comment), flag-on (comment appended, still-open skipped), failure tolerance, and duration formatting
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 rake test 0 failures
- [x] #2 rubocop 0 offenses
- [x] #3 README documents LETSDO_TASK_TIME_COMMENT
- [x] #4 All texts English (TASK-35)
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Extract the shared duration formatter into Letsdo::Duration; make SessionRecorder's summary use it (AC #4).
2. Add Config#task_time_comment? reading LETSDO_TASK_TIME_COMMENT == '1' (default off) (AC #1).
3. New Letsdo::TaskTimeWriteback: given command/cwd/env/stderr, take the recorder's done runs plus a fresh provider snapshot; for each unique exit-0 run whose task id is absent from the snapshot, run '<backlog> task edit <id> --comment letsdo: completed in <dur> --comment-author @letsdo' via Capture; missing/renamed task or failed command warns once per task; never raises; returns the failure count (AC #2, #3).
4. Wire into the CLI Builder stop path (both plain and TUI ensure blocks) through one shared finish_session: recorder.session_stop, write-back when the flag is on (fresh provider re-query, cwd=root), print summary_line and 'N comments not written' when failures > 0; exit code stays 0 (AC #2, #3).
5. Extend the fake_backlog fixture to handle 'task edit' (record argv, configurable exit) for tests.
6. Tests: task_time_writeback_test.rb (off/on, still-open skipped, missing task, failing command, duration format, dedup), config flag, duration formatter; keep rake test and rubocop green (AC #1-#4, DoD #1-#2).
7. Document LETSDO_TASK_TIME_COMMENT in README and docs/config.md (DoD #3), English only (DoD #4).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation:
- Letsdo::Duration (new lib/letsdo/duration.rb) — the one duration formatter; SessionRecorder::SummaryFormat#format_duration now delegates to it, so the stop summary and the task-record comment cannot disagree.
- Letsdo::Config#task_time_comment? — true only for the literal LETSDO_TASK_TIME_COMMENT=1 (default off).
- Letsdo::TaskTimeWriteback (new lib/letsdo/task_time_writeback.rb) — provider-agnostic writer: for each unique exit-0 run whose task is absent from the fresh provider snapshot, runs '<LETSDO_BACKLOG_COMMAND> task edit <id> --comment letsdo: completed in <dur> --comment-author @letsdo' via Capture (cwd = root, env inherited+overrides). Still-open tasks are skipped; a nil (unreadable) snapshot warns once and writes nothing; any failure warns once per task, never raises, and is counted.
- CLI Builder: one shared finish_session(name, recorder) for plain and TUI stop paths — recorder.session_stop, opt-in write-back (fresh provider re-query once), then summary_line and, when failures > 0, 'letsdo: N comment(s) not written'. Exit code stays 0.
- fake_backlog fixture: new 'task edit' branch (records argv, FAKE_BACKLOG_EDIT_FAIL=1 simulates a missing/renamed task or broken CLI).

Verification:
- rake test: 356 runs, 1030 assertions, 0 failures, 0 errors.
- rubocop --no-server lib bin test: 73 files, 0 offenses.
- Tests: duration_test.rb; task_time_writeback_test.rb (comment argv + duration, still-open skipped, failed runs skipped, retry dedup, per-task comments, failing edit warn+count, one failure does not stop others, missing command, unreadable snapshot); config_test.rb flag gating; cli_test.rb flag-off (no edit subprocess), flag-on (comment + @letsdo author), edit-failure (exit 0, warning, '1 comment not written'), and a TUI-mode write-back test.
- README LETSDO_TASK_TIME_COMMENT row + 'Per-task elapsed in the task record (opt-in)' section; docs/config.md table and 'where each variable is read' entry. All new texts English.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Shipped the opt-in per-task elapsed write-back (TASK-63 C3.3). New Letsdo::Duration is the single duration formatter, now also used by the TASK-69 stop summary. Letsdo::Config#task_time_comment? gates on LETSDO_TASK_TIME_COMMENT=1 (off by default). New Letsdo::TaskTimeWriteback re-queries the provider once at stop and, for each unique exit-0 run whose task is absent from the fresh snapshot, runs '<LETSDO_BACKLOG_COMMAND> task edit <id> --comment letsdo: completed in <dur> --comment-author @letsdo' (cwd = root); still-open tasks are skipped, a nil snapshot writes nothing, and failures warn once per task, never raise, and are counted. The CLI Builder now routes plain and TUI stops through one finish_session that prints the summary and 'letsdo: N comments not written' when any write failed; the exit code stays 0. Verified by rake test (356 runs, 1034 assertions, 0 failures/errors) and rubocop over lib/bin/test (73 files, 0 offenses); new duration/writeback/config/CLI tests cover flag-off (no subprocess, no mutation), flag-on (comment + @letsdo author, still-open skipped), failure tolerance, dedup and duration formatting; README and docs/config.md document LETSDO_TASK_TIME_COMMENT.
<!-- SECTION:FINAL_SUMMARY:END -->
