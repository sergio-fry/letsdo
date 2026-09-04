---
id: TASK-74
title: >-
  Agent control: real pause semantics (Control::PauseGate + AgentLoop
  between-runs gate + TUI 'p' suspension, quit-while-paused, SIGHUP)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:26'
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
- [ ] #1 New Letsdo::Control::PauseGate (Mutex-guarded flag: #pause/#resume/#paused?); unit tests prove thread-safe toggle from two threads.
- [ ] #2 AgentLoop accepts optional pause_gate: (default nil = no-op, plain behavior byte-identical; existing loop tests unchanged and green).
- [ ] #3 wrapped_run polls the gate before run_started: while paused no new task is started (injectable sleeper, stop via Letsdo::Stopped still interrupts the gate wait promptly); after resume the queued next task runs; TUI/plain messaging unchanged.
- [ ] #4 TUI 'p' toggles real suspension: mid-run → runner.pause (SIGSTOP) + display freeze with PAUSED badge (existing renderer, log keeps buffering); second 'p' → runner.resume (SIGCONT) + display resumes; between-runs/waiting → gate only, no crash (no/absent runner is a no-op).
- [ ] #5 Footer/key help reflects context: 'p' shown as pause vs resume (metrics.current_task distinguishes mid-run from between-runs); UI texts in English (TASK-35).
- [ ] #6 Quit-while-paused works promptly: subprocess test — pi paused mid-run, then TUI 'q' or SIGTERM → pi terminated + 'letsdo: stopped' + exit 0 in well under the 3s grace (CONT-before-TERM); terminal restored on every path (existing session tests stay green).
- [ ] #7 AgentLoop also traps SIGHUP → same stop path; subprocess test: kill -HUP → clean stop, exit 0.
- [ ] #8 Session#quit sets @stop before Thread.main.raise (no teardown repaints).
- [ ] #9 Tests: pause_gate, agent_loop gate (injected sleeper), session keys (p in running + waiting states with stubbed agent/runner), quit-while-paused + SIGHUP subprocess tests; rake test 0 failures; rubocop 0 offenses.
- [ ] #10 Affected: new lib/letsdo/control.rb (PauseGate), lib/letsdo/agent_loop.rb, lib/letsdo/tui/session.rb, lib/letsdo/cli.rb (gate wiring into Session + AgentLoop), tests, README (keys section).
<!-- AC:END -->
