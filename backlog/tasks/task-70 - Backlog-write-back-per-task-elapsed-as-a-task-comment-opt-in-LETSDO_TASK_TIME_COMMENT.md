---
id: TASK-70
title: >-
  Backlog write-back: per-task elapsed as a task comment (opt-in,
  LETSDO_TASK_TIME_COMMENT)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:10'
updated_date: '2026-09-04 10:27'
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
- [ ] #1 Default off: with LETSDO_TASK_TIME_COMMENT unset or != 1, no task file is ever modified, no extra backlog subprocess runs, and behavior is identical to TASK-69 alone
- [ ] #2 With LETSDO_TASK_TIME_COMMENT=1, at session stop the CLI appends a comment to each exit-0 run's task: backlog task edit <id> --comment 'letsdo: completed in 4m 12s' --comment-author @letsdo (command and cwd from CLI config; duration formatting mm:ss / Xm Ys shared with the TASK-69 summary); a fresh final provider query once at stop excludes still-open tasks from write-back
- [ ] #3 Failure tolerance: a missing/renamed task or a failing backlog command warns once per task on stderr, does not abort the stop path, and the summary line reports 'N comments not written'; the process exit code stays 0
- [ ] #4 The recorder stays provider-agnostic (no backlog knowledge); the write-back is CLI-level and consumes recorder runs only
- [ ] #5 Tests: CLI-level with a fake backlog command in a tempdir project — flag off (no comment), flag on (comment appended with author @letsdo, still-open tasks skipped), failure tolerance, duration formatting; rake test 0 failures; rubocop 0 offenses; README documents the flag
- [ ] #6 All texts English (TASK-35)
<!-- AC:END -->
