---
id: TASK-73
title: >-
  PiRunner: pause/resume (SIGSTOP/SIGCONT to the pi group) + CONT-before-TERM in
  terminate
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:25'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 62000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Core primitive for agent control (TASK-67): Letsdo::PiRunner must be able to freeze and resume a running pi mid-run, and #terminate must be able to kill a frozen child promptly. pi runs in its own process group (pgroup: true, TASK-39); SIGSTOP/SIGCONT to that group (-pid) freeze/resume the whole group at kernel level — no letsdo trap fires, so none of the CRuby 4.0 trap/IO constraints from TASK-39 apply. A SIGSTOPped process does NOT process SIGTERM, so terminate() must SIGCONT first (no-op on a non-stopped process) or quit-while-paused would stall the full grace period before SIGKILL. Design recorded in TASK-67 comments (PAUSE IMPLEMENTATION EVALUATION).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 PiRunner#pause sends SIGSTOP to the pi process group; subprocess test observes the child entering stopped state (e.g. waitpid WUNTRACED or /proc status).
- [ ] #2 PiRunner#resume sends SIGCONT; the child continues and the run completes normally (exit code unchanged).
- [ ] #3 Both #pause and #resume are safe no-ops when no pi is running or the group is gone (nil pid, Errno::ESRCH/EPERM swallowed — same policy as send_signal).
- [ ] #4 PiRunner#terminate sends SIGCONT before SIGTERM; subprocess test: pi stopped via #pause, #terminate returns promptly (well under the 3s grace) and the child is reaped — proves quit-while-paused does not stall.
- [ ] #5 Existing non-paused stop path unchanged: SIGTERM → prompt exit + reap + 128+signal exit-code mapping; all existing pi_runner tests stay green; rake test 0 failures; rubocop 0 offenses.
- [ ] #6 Affected: lib/letsdo/pi_runner.rb, test/pi_runner_test.rb.
<!-- AC:END -->
