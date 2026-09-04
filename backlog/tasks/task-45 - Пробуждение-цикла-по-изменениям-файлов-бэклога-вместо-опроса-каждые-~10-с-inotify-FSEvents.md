---
id: TASK-45
title: >-
  Wake the loop on backlog file changes instead of polling every ~10 s
  (inotify/FSEvents)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-03 21:17'
updated_date: '2026-09-04 10:27'
labels: []
dependencies:
  - TASK-39
priority: medium
type: enhancement
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently Letsdo::AgentLoop polls the backlog once every ~10 s (wait_seconds) while in the wait mode. User requirement: use OS mechanisms to track changes in the backlog folder — inotify (Linux), FSEvents (macOS), etc. — and react promptly: as soon as backlog files change, the loop wakes up immediately, runs task search and selection, without waiting for the 10-second interval. Reference implementation: TASK-8 (Done) — the old bin/agent-loop watched backlog/ via inotify (ctypes, select), excluded .locks, and fell back to periodic polling when inotify was unavailable; the agent's own edits also woke the loop, but the re-check with no open tasks returned it to waiting. Take into account: no external dependencies (inotify via ctypes, as before) or a justified choice (listen/rb-fsevent); fallback polling when the watch is unavailable; excluding service directories (.locks); integration with the interruptible sleeper/self-pipe in AgentLoop — select on wake-fd and watch-fd so SIGINT/SIGTERM stay responsive; no false wake-ups from the agent's own edits (after waking — re-check: no open tasks → wait again).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 While idle the loop blocks on the OS mechanism (inotify on Linux; FSEvents/fallback on macOS) and wakes immediately on backlog/ file changes, without waiting for the 10-second interval
- [ ] #2 After waking, tasks are re-checked: if open tasks exist — the agent picks one; if not — the loop waits again (the agent's own edits do not start the agent without open tasks)
- [ ] #3 The fallback periodic polling (~10 s) is kept when the watch is unavailable (no inotify/FSEvents)
- [ ] #4 SIGINT/SIGTERM response stays fast while idle (integration with the interruptible sleeper/self-pipe in Letsdo::AgentLoop)
- [ ] #5 Backlog service directories (e.g. .locks) are excluded from the watch subscription
- [ ] #6 Tests: deterministic wake-up on a backlog file change (injectable watcher), fallback polling, correct stop; rake test green (0 failures); rubocop 0 offenses
<!-- AC:END -->
