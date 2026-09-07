---
id: TASK-45
title: >-
  Wake the loop on backlog file changes instead of polling every ~10 s
  (inotify/FSEvents)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-03 21:17'
updated_date: '2026-09-07 17:00'
labels: []
dependencies:
  - TASK-39
  - TASK-82
priority: medium
type: enhancement
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently Letsdo::AgentLoop polls the backlog once every ~10 s (wait_seconds) while in the wait mode. User requirement: use OS mechanisms to track changes in the backlog folder — inotify (Linux), FSEvents (macOS), etc. — and react promptly: as soon as backlog files change, the loop wakes up immediately, runs task search and selection, without waiting for the 10-second interval. Reference implementation: TASK-8 (Done) — the old bin/agent-loop watched backlog/ via inotify (ctypes, select), excluded .locks, and fell back to periodic polling when inotify was unavailable; the agent's own edits also woke the loop, but the re-check with no open tasks returned it to waiting. Take into account: no external dependencies (inotify via ctypes, as before) or a justified choice (listen/rb-fsevent); fallback polling when the watch is unavailable; excluding service directories (.locks); integration with the interruptible sleeper/self-pipe in AgentLoop — select on wake-fd and watch-fd so SIGINT/SIGTERM stay responsive; no false wake-ups from the agent's own edits (after waking — re-check: no open tasks → wait again).

Expected loop semantics (scope clarification, 2026-09-07): the wake mechanism changes ONLY the idle phase. The following must stay true and be covered by tests:
- Startup: the loop queries the backlog immediately — the first provider check happens before any wait, so an open task present at launch is picked up right away (no ~10 s delay before the first check).
- After a finished task: the loop re-checks immediately and continues with the remaining/new open tasks — it does not go idle or stop after a single task; the idle phase is entered only when a query returns no open tasks.
- Consequence: inotify/FSEvents gating applies to the idle wait only; it must add no latency between consecutive tasks and must not delay the startup check (both remain immediate provider queries).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 While idle the loop blocks on the OS mechanism (inotify on Linux; FSEvents/fallback on macOS) and wakes immediately on backlog/ file changes, without waiting for the 10-second interval
- [ ] #2 After waking, tasks are re-checked: if open tasks exist — the agent picks one; if not — the loop waits again (the agent's own edits do not start the agent without open tasks)
- [ ] #3 The fallback periodic polling (~10 s) is kept when the watch is unavailable (no inotify/FSEvents)
- [ ] #4 SIGINT/SIGTERM response stays fast while idle (integration with the interruptible sleeper/self-pipe in Letsdo::AgentLoop)
- [ ] #5 Backlog service directories (e.g. .locks) are excluded from the watch subscription
- [ ] #6 Tests: deterministic wake-up on a backlog file change (injectable watcher), fallback polling, correct stop; rake test green (0 failures); rubocop 0 offenses
- [ ] #7 Loop semantics preserved: startup queries the backlog immediately (no wait before the first check), and after a finished task the loop immediately re-checks and continues with further open tasks; the idle/wait phase is entered only when no open tasks remain
- [ ] #8 The inotify/FSEvents wake replaces the idle-phase polling only: it adds no latency between consecutive tasks and does not delay the startup check (those remain immediate provider queries)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add Letsdo::Watcher (lib/letsdo/watcher.rb): OS file-change watcher for the backlog folder. Linux: inotify via Fiddle (no external gem), masking IN_CREATE/IN_MODIFY/IN_CLOSE_WRITE/IN_DELETE/IN_MOVED_*; excludes .locks entries. macOS/other: fall back to a self-pipe timeout (periodic polling, same semantics as the plain sleeper) — no external FSEvents dep (justified: reference impl also fell back when inotify unavailable; FSEvents via Fiddle would need CFRunLoop).
2. Wait is interruptible: IO.select on the inotify fd (if any) + an internal self-pipe wake fd; returns :change/:wake/:timeout. A Ruby signal trap raising Letsdo::Stopped interrupts the select, keeping SIGINT/SIGTERM fast while idle. #wake + self-pipe supports explicit stop.
3. Wire Letsdo::AgentLoop: accept watcher:/watch_path: opts; build the idle sleeper from the watcher so the watcher replaces ONLY the idle-phase wait; start the watcher before the loop and close it in ensure. Startup and after-task re-checks stay immediate provider queries (Loop unchanged).
4. Wire Letsdo::CLILaunch: pass watcher watching <root>/backlog.
5. Tests: watcher_test.rb (deterministic wake on a file change, excluded .locks, timeout, wake, fallback) + agent_loop_test.rb integration with an injectable fake watcher (wake-up re-checks and runs a task; fallback polling waits; correct stop). rake test green, rubocop 0 offenses.
<!-- SECTION:PLAN:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @developer
created: 2026-09-07 11:56
---
Parked to To Do on user request (2026-09-07): critical TUI bug TASK-82 (blank activity pane — blocks using the current system) takes priority. No code changes for this task were present in the working tree. Resume implementation only after TASK-82 is resolved (dependency added).
---

author: @developer
created: 2026-09-07 14:03
---
Scope refinement from the product owner (2026-09-07): the loop must check for open tasks immediately at startup and, after finishing a task, re-check and continue with the next tasks instead of stopping — confirmed this is already Letsdo::Loop behavior (TASK-39), so the watcher must only replace the idle-phase wait. Added explicit semantics to the description and AC #7/#8.
---

author: @developer
created: 2026-09-07 17:00
---
Implementation attempt (2026-09-07) — REVERTED. While In Progress (@developer) a working draft was written, then rolled back on product-owner request; task returned to To Do.

What was done:
- lib/letsdo/watcher.rb (new): Letsdo::Watcher — inotify via Fiddle (no external gem) with a self-pipe polling fallback; interruptible IO.select on the inotify fd + wake self-pipe; excludes .locks; returns :change/:wake/:timeout.
- lib/letsdo/agent_loop.rb: require watcher; start_watcher in run; idle_sleeper returns watcher.wait when a watcher is present; close in ensure.
- lib/letsdo/cli/launch.rb: build a default Letsdo::Watcher(path: <root>/backlog) and pass it into AgentLoop.
- lib/letsdo.rb: require watcher.

Problem found during verification: the default watcher made AgentLoop#idle_sleeper return watcher.wait instead of the caller-injected sleeper, so tests that inject a stop/control sleeper hang in an infinite idle wait and rake test never finishes. The verification run `timeout 300 rake test 2>&1 | tail -40` hung; timeout killed only rake and orphaned the test loader holding the output pipe, so the tool call never returned. Both root causes are tracked separately as TASK-84.

Decision: implementation reverted (3 lib files restored to HEAD, watcher.rb removed) so the task can be re-attempted cleanly. The scope clarification in the description (immediate startup check + continue after each task; watcher replaces only the idle phase) remains valid guidance.
---
<!-- COMMENTS:END -->
