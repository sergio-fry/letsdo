---
id: TASK-56
title: >-
  Providers::Backlog adapter: move backlog_tasks.rb into Letsdo::Providers with
  normalized Task shape
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 07:37'
updated_date: '2026-09-10 16:27'
labels: []
dependencies:
  - TASK-42
references:
  - TASK-51
priority: medium
type: enhancement
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Part of the TASK-51 spike (task provider adapter seam), Phase 2 of the TASK-50 refactoring layout: lib/letsdo/providers/ is the reserved namespace for task providers. Today Letsdo::BacklogTasks is hardwired to the backlog CLI and its JSON schema, and Letsdo::AgentLoop#task_label reads task["id"] — the only business-layer consumer of a tracker-specific field. This task moves the provider into Letsdo::Providers::Backlog and introduces the normalized Letsdo::Providers::Task value object, so business logic stops depending on the backlog JSON keys. Behavior stays identical: same command line, same env/fallbacks, same exit codes, plain output byte-identical; Letsdo::Loop's empty-Array-vs-nil contract is untouched.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 New lib/letsdo/providers/task.rb: Letsdo::Providers::Task — immutable value object with attr readers id/title/status/priority/assignees (assignees Array<String>) and #to_s returning the id when present, a readable summary otherwise (mirrors the current task_label fallback)
- [x] #2 lib/letsdo/backlog_tasks.rb moves to lib/letsdo/providers/backlog.rb as Letsdo::Providers::Backlog: identical command line (backlog task list --assignee <handle> --exclude-status Done --json), identical injection points (handle/command/cwd/env), identical rescues (ENOENT, non-zero exit, JSON parse errors, non-array tasks -> nil); each JSON row mapped onto Letsdo::Providers::Task
- [x] #3 Letsdo::AgentLoop#task_label consumes the normalized shape (task.to_s / task.id); the only business-layer field read, output byte-identical ('letsdo: running <name> for <task id>') with the same fallback for a missing id; no other production code reads task fields
- [x] #4 Letsdo::CLI#run_agent_plain and #run_agent_tui construct Letsdo::Providers::Backlog with the same handle/command/cwd/env args as today; LETSDO_BACKLOG_COMMAND keeps working (via Letsdo::Config if TASK-53 has landed)
- [x] #5 Tests migrated: test/backlog_tasks_test.rb -> test/providers/backlog_test.rb reusing fake_backlog scenarios (open/empty/fail/malformed/missing command/argv capture) against Letsdo::Providers::Backlog, plus a small Task unit test; lib/letsdo.rb requires the new files, the old Letsdo::BacklogTasks constant is removed (no compat alias). rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35)
- [x] #6 #call returns Array<Task> (empty = no open tasks) or nil (tracker unreadable) — Letsdo::Loop's empty-vs-nil semantics preserved exactly; test/loop_test.rb and test/agent_loop_test.rb pass unchanged (fake providers)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Fix Providers::Backlog#call: Task.new(**t) fails because JSON.parse returns string keys. Wrap with symbolize_keys or map explicitly.\n2. Delete old test/backlog_tasks_test.rb (references removed Letsdo::BacklogTasks constant).\n3. Add a Task unit test to test/providers/backlog_test.rb (value object, #to_s with id, #to_s without id).\n4. Run rake test — 0 failures.\n5. Run rubocop over lib/, bin/, test/ — 0 offenses.\n6. Verify all 6 acceptance criteria with objective evidence.\n7. Move task to Done, write final summary, commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Task verified complete. All 6 acceptance criteria met: (1) Providers::Task value object with id/title/status/priority/assignees and #to_s in lib/letsdo/providers/task.rb. (2) Providers::Backlog in lib/letsdo/providers/backlog.rb with identical command line, injection points, rescues, and JSON-to-Task mapping. (3) AgentLoop#task_label consumes task.id / task.to_s — output byte-identical. (4) CLI::Builder#provider_for constructs Providers::Backlog with same args. (5) Tests migrated: test/providers/backlog_test.rb with ProvidersBacklogTest + ProvidersTaskTest; old backlog_tasks_test.rb deleted; rake test green (251 runs, 0 failures); rubocop 0 offenses on changed files. (6) #call returns Array<Task> or nil — empty-vs-nil semantics preserved. Verification evidence: rake test and rubocop output recorded.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Moved Letsdo::BacklogTasks to Letsdo::Providers::Backlog and introduced the Letsdo::Providers::Task value object so business logic no longer depends on tracker-specific JSON keys. AgentLoop#task_label now reads task.id/task.to_s. CLI::Builder#provider_for constructs Providers::Backlog with the same args. Tests migrated to test/providers/backlog_test.rb (ProvidersBacklogTest + ProvidersTaskTest); old backlog_tasks_test.rb and backlog_tasks.rb deleted. Verified: rake test green (251 runs, 752 assertions, 0 failures), rubocop 0 offenses on changed files.
<!-- SECTION:FINAL_SUMMARY:END -->
