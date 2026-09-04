---
id: TASK-56
title: >-
  Providers::Backlog adapter: move backlog_tasks.rb into Letsdo::Providers with
  normalized Task shape
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:37'
updated_date: '2026-09-04 07:37'
labels: []
dependencies:
  - TASK-42
references:
  - TASK-51
type: enhancement
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Part of the TASK-51 spike (task provider adapter seam), Phase 2 of the TASK-50 refactoring layout: lib/letsdo/providers/ is the reserved namespace for task providers. Today Letsdo::BacklogTasks is hardwired to the backlog CLI and its JSON schema, and Letsdo::AgentLoop#task_label reads task["id"] — the only business-layer consumer of a tracker-specific field. This task moves the provider into Letsdo::Providers::Backlog and introduces the normalized Letsdo::Providers::Task value object, so business logic stops depending on the backlog JSON keys. Behavior stays identical: same command line, same env/fallbacks, same exit codes, plain output byte-identical; Letsdo::Loop's empty-Array-vs-nil contract is untouched.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 New lib/letsdo/providers/task.rb: Letsdo::Providers::Task — immutable value object with attr readers id/title/status/priority/assignees (assignees Array<String>) and #to_s returning the id when present, a readable summary otherwise (mirrors the current task_label fallback)
- [ ] #2 lib/letsdo/backlog_tasks.rb moves to lib/letsdo/providers/backlog.rb as Letsdo::Providers::Backlog: identical command line (backlog task list --assignee <handle> --exclude-status Done --json), identical injection points (handle/command/cwd/env), identical rescues (ENOENT, non-zero exit, JSON parse errors, non-array tasks -> nil); each JSON row mapped onto Letsdo::Providers::Task
- [ ] #3 Letsdo::AgentLoop#task_label consumes the normalized shape (task.to_s / task.id); the only business-layer field read, output byte-identical ('letsdo: running <name> for <task id>') with the same fallback for a missing id; no other production code reads task fields
- [ ] #4 Letsdo::CLI#run_agent_plain and #run_agent_tui construct Letsdo::Providers::Backlog with the same handle/command/cwd/env args as today; LETSDO_BACKLOG_COMMAND keeps working (via Letsdo::Config if TASK-53 has landed)
- [ ] #5 Tests migrated: test/backlog_tasks_test.rb -> test/providers/backlog_test.rb reusing fake_backlog scenarios (open/empty/fail/malformed/missing command/argv capture) against Letsdo::Providers::Backlog, plus a small Task unit test; lib/letsdo.rb requires the new files, the old Letsdo::BacklogTasks constant is removed (no compat alias). rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35)
- [ ] #6 #call returns Array<Task> (empty = no open tasks) or nil (tracker unreadable) — Letsdo::Loop's empty-vs-nil semantics preserved exactly; test/loop_test.rb and test/agent_loop_test.rb pass unchanged (fake providers)
<!-- AC:END -->
