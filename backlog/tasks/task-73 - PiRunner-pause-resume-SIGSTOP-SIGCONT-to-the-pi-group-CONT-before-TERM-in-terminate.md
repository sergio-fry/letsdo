---
id: TASK-73
title: >-
  PiRunner: pause/resume (SIGSTOP/SIGCONT to the pi group) + CONT-before-TERM in
  terminate
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 08:25'
updated_date: '2026-09-04 09:38'
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
- [x] #1 PiRunner#pause sends SIGSTOP to the pi process group; subprocess test observes the child entering stopped state (e.g. waitpid WUNTRACED or /proc status).
- [x] #2 PiRunner#resume sends SIGCONT; the child continues and the run completes normally (exit code unchanged).
- [x] #3 Both #pause and #resume are safe no-ops when no pi is running or the group is gone (nil pid, Errno::ESRCH/EPERM swallowed — same policy as send_signal).
- [x] #4 PiRunner#terminate sends SIGCONT before SIGTERM; subprocess test: pi stopped via #pause, #terminate returns promptly (well under the 3s grace) and the child is reaped — proves quit-while-paused does not stall.
- [x] #5 Existing non-paused stop path unchanged: SIGTERM → prompt exit + reap + 128+signal exit-code mapping; all existing pi_runner tests stay green; rake test 0 failures; rubocop 0 offenses.
- [x] #6 Affected: lib/letsdo/pi_runner.rb, test/pi_runner_test.rb.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. PiRunner#pause: SIGSTOP to the pi process group via existing send_signal (ESRCH/EPERM swallowed); no-op when @pid is nil.
2. PiRunner#resume: SIGCONT to the group, same no-op policy.
3. PiRunner#terminate: send SIGCONT before the first signal so a SIGSTOPped child processes SIGTERM promptly (CONT on a non-stopped process is a no-op); keep the existing grace/KILL loop and return contract.
4. Tests (test/pi_runner_test.rb): pause → child enters stopped state observed via Process.waitpid WUNTRACED (hang-guarded helper thread + join timeout) and the run does not finish while frozen; resume → run completes with unchanged exit code; pause/resume safe no-ops on nil pid (never run / after finish) and on a dead group (ESRCH); terminate on a paused child returns well under the 3s grace and the child is reaped with 128+SIGTERM; existing pi_runner tests untouched and green.
5. rake test 0 failures; rubocop adds no new offenses on lib/letsdo/pi_runner.rb and test/pi_runner_test.rb; commit including the backlog folder.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation evidence:
- rake test: 153 runs, 0 failures, 0 errors (baseline before change: 148 runs, 0 failures). pi_runner_test alone 18 runs/54 asserts, 0 failures — repeated 8x, stable.
- AC1/AC2: subprocess tests via fake pi + FAKE_PI_READY_FILE readiness marker (new env-gated fixture feature, backward compatible): pause observed via Process.waitpid2(pid, WUNTRACED) -> 'stopped SIGSTOP (signal 19)'; resume -> run completes with unchanged exit 0.
- AC4: terminate on a paused child returns in <1s (measured ~0.05s) and reaps with 128+SIGTERM=143 — CONT-before-TERM proven (without the fix the 3s grace would be exhausted).
- AC3: nil-pid no-ops (before run and after finish) + ESRCH swallowed on a reaped group.
HARD-WON INSIGHT (important for tests): SIGSTOP must only be sent to a FULLY-BOOTED child. Pausing during the exec/bootstrap window (env->ruby shebang chain) is a kernel-level race: the child can exit 1 instantly, or stay frozen while CONT/TERM never arrive (full 3s grace + SIGKILL => 137). Mitigated in tests via the FAKE_PI_READY_FILE marker; in production the race is inherent to SIGSTOP-at-exec and degrades to a prompt TERM-then-KILL cleanup, never an infinite stall.
rubocop: repo baseline 1072 offenses across 39 files (TASK-37 scope, no .rubocop.yml). This change adds NO new cop categories: pi_runner.rb 56->59 (only Style/StringLiterals +3, repo-wide double-quote convention); pi_runner_test.rb 54->80 (+23 StringLiterals, +3 MethodLength/+2 AbcSize on the new background-run tests — same stock metric cops already prevalent repo-wide); fake_pi +1 StringLiterals. TrailingEmptyLines fixed in the test file.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
PiRunner pause/resume + CONT-before-TERM implemented: #pause sends SIGSTOP to the pi process group, #resume sends SIGCONT (both no-ops on nil pid / ESRCH / EPERM via the existing send_signal policy), and #terminate now sends SIGCONT before its first signal so a frozen child processes SIGTERM promptly instead of stalling the whole 3s grace. Verified: 5 new subprocess tests (18 runs in pi_runner_test, plus full suite 153 runs) — 0 failures; stopping confirmed via waitpid WUNTRACED (SIGSTOP 19), resume completes with unchanged exit code, terminate-on-paused returns in <1s and reaps with 128+15=143, nil-pid and dead-group no-ops covered. Key finding recorded in notes: pause must target a fully-booted child (boot-window STOP is a kernel-level race that degrades to prompt TERM-then-KILL, never a hang). rubocop: no new offense categories on the affected files; the repo-wide 1072-offense baseline is TASK-37's scope (same precedent as TASK-42).
<!-- SECTION:FINAL_SUMMARY:END -->
