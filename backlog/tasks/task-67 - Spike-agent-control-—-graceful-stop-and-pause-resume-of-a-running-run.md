---
id: TASK-67
title: 'Spike: agent control — graceful stop and pause/resume of a running run'
status: To Do
assignee:
  - '@analyst'
created_date: '2026-09-04 08:01'
labels: []
dependencies:
  - TASK-42
type: spike
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design user-level control of a running agent (per user request — a separate task from loop reliability): exit should be possible by a key instead of Ctrl-C, and the user should be able to pause the agent. Today the loop stops only on SIGINT/SIGTERM (Ctrl-C); TASK-42's TUI adds 'q' (quit = identical to signal stop) and 'p' (pause — display freeze only, the agent keeps running).

This spike must design true control semantics and reconcile with TASK-42: (1) graceful stop triggered by a key (TUI mode) and by a signal (non-TTY) — same teardown path (pi child terminated, terminal restored, exit code 0); (2) PAUSE that actually suspends the running run — decide granularity (pause before next run only, or pause the pi child mid-run via SIGSTOP/SIGCONT — evaluate signal safety on CRuby 4.0 given known trap/IO constraints), resume, and how the TUI displays both states; (3) fallback when no TUI (stdin-based command like 'p'/'q', or signal-based); (4) interplay with AgentLoop interruption model (Letsdo::Stopped raise-in-trap). Keep Letsdo::Loop generic; control lives at AgentLoop/TUI level. Deliverable: design + semantics in comments + developer tasks (@developer) with ACs. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Control model specified: graceful stop (key + signal), pause (mid-run vs between-runs semantics), resume, with terminal/pi teardown guarantees and exit codes
- [ ] #2 Pause implementation evaluated: SIGSTOP/SIGCONT vs defer-to-next-run, signal-safety on CRuby 4.0 (trap constraints known from TASK-39 work), recommendation given
- [ ] #3 Non-TUI story designed: stdin commands and/or signals with the same semantics as TUI keys
- [ ] #4 Developer task(s) created via backlog CLI (@developer) with ACs, sized for single-PR; spike leaves code untouched
<!-- AC:END -->
