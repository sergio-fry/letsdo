---
id: TASK-84
title: >-
  Bug: agent hangs on a rake-test tool call — Watcher bypasses the injected
  sleeper (rake test never finishes) and timeout orphans the test loader holding
  the pipe
status: Done
assignee:
  - '@developer'
created_date: '2026-09-07 16:58'
updated_date: '2026-09-07 18:07'
labels: []
dependencies: []
priority: medium
type: bug
ordinal: 73000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Case (2026-09-07, live letsdo agent working on TASK-45): the agent's verification command `cd … && timeout 300 rake test 2>&1 | tail -40` never returned. The tool call started 16:09:27 and was still blocked 16+ minutes later; the letsdo TUI showed task TASK-45 running with no tool completion. The agent was stuck on a hung tool call.

Root cause 1 — Watcher bypasses the injected sleeper (makes rake test hang): in-progress TASK-45 wiring made Letsdo::CLI#launch always build a default Letsdo::Watcher (backlog_watcher), and AgentLoop#idle_sleeper returns watcher.wait whenever a watcher is present — replacing the caller-injected sleeper. Tests that inject a sleeper to stop the loop (e.g. stop_on_first_wait) are now bypassed, so the idle loop runs forever in watcher.wait and the test never returns → `rake test` never finishes. Reproduced: test_without_open_tasks_the_loop_waits hangs (>24 s; normally <1 s).

Root cause 2 — timeout leaves an orphan holding the pipe: `timeout 300 rake test … | tail -40` killed only its direct child rake at 16:14:27; the ruby test loader was orphaned (reparented to PID 1) and kept running the hung suite while holding the stdout pipe open, so tail never saw EOF and the bash tool never returned to the agent even after the timeout fired.

Related: introduced by the in-progress TASK-45 work; found while the agent was implementing it. Separate investigation/fix (not part of TASK-45 scope).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A CLI test that injects a control/stop sleeper completes normally even when the loop watcher is enabled: an explicitly provided sleeper is honored and not overridden by the watcher idle path
- [x] #2 The full rake test suite completes without hanging — no test enters an infinite idle wait; the suite finishes in normal time
- [x] #3 A timeout-wrapped command run by the agent (e.g. `timeout N cmd | tail`) does not leave an orphaned process holding the output pipe after the timeout fires, so the agent tool call returns; agent/tool handling is robust to a timed-out child
- [x] #4 Regression guard covers sleeper + watcher coexistence; rake test green (0 failures) and rubocop 0 offenses
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add Letsdo::Watcher (lib/letsdo/watcher.rb): inotify via Fiddle (no external gem) with a self-pipe polling fallback; interruptible IO.select on the inotify fd + wake self-pipe; excludes .locks; returns :change/:wake/:timeout.
2. Wire Letsdo::AgentLoop with the CORRECT precedence (the bug): @sleeper = opts[:sleeper] || watcher_sleeper || default — an explicitly injected sleeper always wins over the watcher idle path; build the watcher from watcher:/watch_path: opts and close it in ensure.
3. Wire Letsdo::CLILaunch to build a default Letsdo::Watcher(path: <root>/backlog) and pass it into AgentLoop; require watcher in lib/letsdo.rb.
4. Harden Letsdo::Capture (root cause 2): spawn the child in its own process group and, when the wait is interrupted, kill+reap the whole group instead of detaching — a killed child can no longer leave grandchildren holding the stdout/stderr pipes.
5. Tests: watcher_test.rb (deterministic wake on file change, .locks excluded, timeout, wake, fallback); agent_loop + cli regression guard (injected sleeper wins over an enabled watcher); capture_test.rb (interrupt kills the child group).
6. Verify rake test green (0 failures) and rubocop 0 offenses.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented the fix: Letsdo::Watcher (inotify via Fiddle + polling fallback) wired into AgentLoop with the correct sleeper precedence (injected sleeper always wins over the watcher idle path) and into CLILaunch (default watcher on <root>/backlog); Letsdo::Capture now spawns its child in its own process group and kills+reaps the whole group on interruption. Validation: rake test 208 runs / 0 failures / 0 errors; rubocop 1.77.0 (CI) and 1.90.0 both 0 offenses.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed both root causes. (1) Sleeper/watcher precedence: added Letsdo::Watcher and wired AgentLoop so an explicitly injected sleeper is honored and never overridden by the watcher idle path (CLI builds a default backlog watcher; the regression guard test_injected_sleeper_wins_over_the_watcher proves the precedence). (2) Orphaned process holding the pipe: Letsdo::Capture runs its child in its own process group and terminates the whole group when the wait is interrupted, so a stopped capture leaves no grandchild holding the stdout/stderr pipes. Verified with rake test (208 runs, 0 failures, 0 errors, ~14s) and rubocop 1.77.0 (0 offenses).
<!-- SECTION:FINAL_SUMMARY:END -->
