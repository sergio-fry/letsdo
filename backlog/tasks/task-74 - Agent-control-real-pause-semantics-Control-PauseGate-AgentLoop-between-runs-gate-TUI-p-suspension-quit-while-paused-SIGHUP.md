---
id: TASK-74
title: >-
  Agent control: real pause semantics (Control::PauseGate + AgentLoop
  between-runs gate + TUI 'p' suspension, quit-while-paused, SIGHUP)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 08:26'
updated_date: '2026-09-04 10:09'
labels: []
dependencies:
  - TASK-42
  - TASK-73
priority: high
type: enhancement
ordinal: 63000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implements the pause semantics designed in TASK-67 (comments: PAUSE IMPLEMENTATION EVALUATION, CONTROL MODEL, NON-TUI STORY + RECONCILIATION): 'p' in the TUI must actually suspend the running run, not just freeze the display (TASK-42's current display-freeze stays as the visual part). Mid-run pause = SIGSTOP to the pi group via PiRunner#pause (TASK-73); between-runs/waiting pause = a shared thread-safe Control::PauseGate polled by AgentLoop#wrapped_run before starting a run. Letsdo::Loop stays generic — control lives at AgentLoop/TUI level; the gate is a new param (default nil/no-op so plain mode stays byte-identical). One-stop-path guarantee (TASK-67 CONTROL MODEL): 'q'/stop while paused must exit promptly thanks to CONT-before-TERM (TASK-73). Optional hardening: trap SIGHUP like SIGINT/SIGTERM so a closed terminal cleans up pi instead of leaving an orphaned group. Design details: Session 'p' sets the gate FIRST then runner.pause (ESRCH no-op when between runs); footer/PAUSED display stays via existing renderer; Session#quit should set @stop before Thread.main.raise to avoid teardown repaints.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 New Letsdo::Control::PauseGate (Mutex-guarded flag: #pause/#resume/#paused?); unit tests prove thread-safe toggle from two threads.
- [x] #2 AgentLoop accepts optional pause_gate: (default nil = no-op, plain behavior byte-identical; existing loop tests unchanged and green).
- [x] #3 wrapped_run polls the gate before run_started: while paused no new task is started (injectable sleeper, stop via Letsdo::Stopped still interrupts the gate wait promptly); after resume the queued next task runs; TUI/plain messaging unchanged.
- [x] #4 TUI 'p' toggles real suspension: mid-run → runner.pause (SIGSTOP) + display freeze with PAUSED badge (existing renderer, log keeps buffering); second 'p' → runner.resume (SIGCONT) + display resumes; between-runs/waiting → gate only, no crash (no/absent runner is a no-op).
- [x] #5 Footer/key help reflects context: 'p' shown as pause vs resume (metrics.current_task distinguishes mid-run from between-runs); UI texts in English (TASK-35).
- [x] #6 Quit-while-paused works promptly: subprocess test — pi paused mid-run, then TUI 'q' or SIGTERM → pi terminated + 'letsdo: stopped' + exit 0 in well under the 3s grace (CONT-before-TERM); terminal restored on every path (existing session tests stay green).
- [x] #7 AgentLoop also traps SIGHUP → same stop path; subprocess test: kill -HUP → clean stop, exit 0.
- [x] #8 Session#quit sets @stop before Thread.main.raise (no teardown repaints).
- [ ] #9 Tests: pause_gate, agent_loop gate (injected sleeper), session keys (p in running + waiting states with stubbed agent/runner), quit-while-paused + SIGHUP subprocess tests; rake test 0 failures; rubocop 0 offenses.
- [ ] #10 Affected: new lib/letsdo/control.rb (PauseGate), lib/letsdo/agent_loop.rb, lib/letsdo/tui/session.rb, lib/letsdo/cli.rb (gate wiring into Session + AgentLoop), tests, README (keys section).
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. New lib/letsdo/control.rb: Letsdo::Control::PauseGate — Mutex-guarded flag (#pause/#resume/#paused?), thread-safe (TASK-67 design).
2. AgentLoop: optional pause_gate: param (default nil = no-op); wrapped_run polls the gate before run_started with an injectable sleeper (Letsdo::Stopped interrupts the wait); trap SIGHUP like SIGINT/SIGTERM.
3. Tui::Session: 'p' toggle → real suspension (runner.pause/resume via stubbed agent runner + gate); PAUSED badge via existing renderer; footer hint pause-vs-resume by metrics.current_task; quit sets @stop before Thread.main.raise.
4. Cli wiring (TUI path): create PauseGate, pass to Session and AgentLoop.
5. Renderer: footer text 'p pause' vs 'p resume' (context-aware), English (TASK-35).
6. Tests: control_test (PauseGate thread-safety), agent_loop gate tests (injected sleeper), session 'p' tests (running + waiting states, stubbed runner), quit-while-paused + SIGHUP subprocess tests; rake test green.
7. README keys section + footer/state docs update; git commit incl. backlog.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation (2026-09-04): rake test green on 4 consecutive full runs (171 runs, 538-542 assertions, 0 failures, 0 errors); targeted stress of the subprocess tests (test/agent_loop_test.rb + test/tui_session_test.rb, 3 runs) also green. New tests present: test/control_test.rb (PauseGate thread-safety), agent_loop gate tests with injected sleeper, test_quit_while_paused_restores_the_terminal_and_exits_zero, SIGHUP subprocess test in agent_loop_test. AC#9 rubocop part NOT checked: the repo has no .rubocop.yml and rubocop is not a dev dependency or CI step; default-config rubocop reports 1159 pre-existing offenses project-wide (110 in the touched files), so '0 offenses' is not verifiable/meaningful here — flag for a separate tooling decision.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented real pause semantics: Letsdo::Control::PauseGate (new lib/letsdo/control.rb, Mutex-guarded, thread-safe), AgentLoop polls it before run_started (injectable sleeper, stopped-interruptible, plain mode byte-identical via default nil); TUI 'p' now suspends mid-run pi via PiRunner#pause (SIGSTOP) / resume (SIGCONT) and toggles the gate between runs; footer flips between 'p pause'/'p resume' (renderer + tests); quit sets @stop before Thread.main.raise; SIGHUP trapped like INT/TERM (agent_loop), PiRunner#terminate reaps with WNOHANG so a signal-killed paused child cannot stall the stop. Verified: rake test 171 runs, 0 failures, 0 errors (4 consecutive runs), subprocess stress green; CHANGELOG + docs/usage.md updated. AC 1-8 checked; AC 9 tests part proven, rubocop part not checked (no rubocop config in repo — see notes).
<!-- SECTION:FINAL_SUMMARY:END -->
