---
id: TASK-67
title: 'Spike: agent control — graceful stop and pause/resume of a running run'
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 08:01'
updated_date: '2026-09-04 08:26'
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
- [x] #1 Control model specified: graceful stop (key + signal), pause (mid-run vs between-runs semantics), resume, with terminal/pi teardown guarantees and exit codes
- [x] #2 Pause implementation evaluated: SIGSTOP/SIGCONT vs defer-to-next-run, signal-safety on CRuby 4.0 (trap constraints known from TASK-39 work), recommendation given
- [x] #3 Non-TUI story designed: stdin commands and/or signals with the same semantics as TUI keys
- [x] #4 Developer task(s) created via backlog CLI (@developer) with ACs, sized for single-PR; spike leaves code untouched
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Study current control paths: AgentLoop signals/raise-in-trap, PiRunner terminate, TUI Session q/p keys (TASK-42 in-progress code), TASK-39 CRuby 4.0 trap constraints.
2. Verify graceful-stop unification: 'q'/Ctrl-C key (TUI) and SIGINT/SIGTERM (non-TTY) both converge on Letsdo::Stopped raised into the main thread — same PiRunner terminate + terminal restore + exit 0.
3. Evaluate pause: SIGSTOP/SIGCONT to the pi group vs defer-to-next-run; signal safety on CRuby 4.0 (no letsdo trap involved — out-of-band kernel freeze of the child group; reader stays blocked on the pipe; CONT-before-TERM needed in terminate() so a frozen child is killable).
4. Design pause semantics: mid-run = SIGSTOP pi group (+ display freeze as in TASK-42); between-runs/waiting = PauseGate flag polled by AgentLoop#wrapped_run before starting a run; TUI display of both states.
5. Design non-TUI story: stdin line commands ('p'/'q') on TTY stdin in plain mode with identical semantics; SIGINT/SIGTERM remain the stop path; SIGTSTP/Ctrl-Z rejected (job-control trap clash); SIGHUP hardening recommended.
6. Record design+semantics in comments, create @developer tasks with ACs (sized single-PR), verify ACs, final summary, Done, commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation (all ACs verified with objective evidence):
#1 Control model specified and VERIFIED against the actual code: Tui::Session#quit raises Letsdo::Stopped via Thread.main.raise (input thread), AgentLoop#on_signal raises it from the trap — both unwind the same PiRunner rescue (terminate + reap + streamer.finish) -> AgentLoop -> exit 0; terminal restored by Session#run ensure. Confirmed reading lib/letsdo/pi_runner.rb, agent_loop.rb, tui/session.rb, errors.rb.
#2 Pause evaluation recorded with recommendation (Option A SIGSTOP/SIGCONT + PauseGate) incl. CRuby 4.0 analysis (no letsdo trap fires — kill targets the child group only; CONT-before-TERM requirement for frozen-child termination).
#3 Non-TUI story designed (stdin 'p'/'q' on TTY stdin; signal-only otherwise; SIGTSTP rejected; SIGHUP hardening folded into TASK-74).
#4 Developer tasks TASK-73/74/75 created via backlog CLI, each assigned @developer with testable ACs, deps chain 73 <- 74 (dep 42,73) <- 75 (dep 74), each sized for a single PR; code untouched by the spike (only backlog/ task metadata changed via CLI; verified git status shows pre-existing TASK-42 developer WIP intact, no lib/test edits by analyst).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-04 08:25
---
CONTROL MODEL — graceful stop unification (verified against current code):
Both stop triggers already converge on ONE teardown path on the main thread — Letsdo::Stopped (Exception, non-StandardError — nothing rescues it accidentally):
* TUI key 'q'/Ctrl-C: Tui::Session#quit does Thread.main.raise(Letsdo::Stopped) from the input thread (NOT from a trap — strictly safer on CRuby 4.0 than raise-in-trap; CRuby delivers a thread-level raise promptly, no trap/IO interaction).
* Signals SIGINT/SIGTERM (non-TTY): AgentLoop#on_signal (raise-in-trap) sends one-shot SIGTERM to the pi group (PiRunner#terminate_now — no IO/sleep, trap-safe) and raises Letsdo::Stopped.
Both unwind the SAME chain: PiRunner#run rescues Letsdo::Stopped -> full terminate (TERM, grace 3s, KILL) + wait2 reap + streamer.finish -> re-raise; AgentLoop#run catches -> 'letsdo: stopped' -> exit 0; Tui::Session#run ensure restores the terminal (leave alt screen) and joins the input thread. Verified in lib/letsdo/pi_runner.rb, agent_loop.rb, tui/session.rb, errors.rb. Exit code on stop = 0 in both modes; agent-run failure codes are unchanged (TASK-68 policy, out of scope).
Remaining small gap (developer task): Session#quit sets @stop only later in teardown -> the input thread may repaint a few frames during unwind; set @stop = true before Thread.main.raise. No behavioral risk.
---

author: @analyst
created: 2026-09-04 08:25
---
PAUSE IMPLEMENTATION EVALUATION — SIGSTOP/SIGCONT (mid-run) + PauseGate (between-runs):

Option A — SIGSTOP/SIGCONT to the pi process group (true mid-run freeze). RECOMMENDED.
Signal-safety on CRuby 4.0 (ruby 4.0.2, M:N threads): the TASK-39 trap constraints (traps not run during Thread#join, deferred with another thread on IO, IO.select not woken) DO NOT APPLY here, because no letsdo trap fires: SIGSTOP/SIGCONT are sent by letsdo to the CHILD group (-pid, Process.spawn pgroup:true) via a plain async-signal-safe Process.kill. SIGSTOP is uncatchable by design — the pi group (pi + any bash tool children, all inherit the group) freezes deterministically at kernel level; letsdo's own main thread stays exactly where the stop design already expects it — blocked in PiRunner#read_pi_stream on the pipe (EOF never comes while frozen; no data, no unwinding). Resume = SIGCONT: pipe flushes buffered events, the read continues, streamer/log resume. The TUI input thread keeps polling the terminal (never frozen) so 'p'/'q' work while paused, and Thread.main.raise still interrupts the blocking read. No deadlock, no busy loop.
Termination of a FROZEN child: SIGTERM is NOT processed by a SIGSTOPped process — the current terminate() grace loop would wait out the full 3s then SIGKILL. Fix (mandatory with option A): PiRunner#terminate sends SIGCONT BEFORE SIGTERM (SIGCONT to a non-stopped process is a no-op — safe unconditionally), then TERM/grace/KILL as today. Quit-while-paused then stops promptly.
Granularity: SIGSTOP freezes model generation AND tool executions (kernel-level, whole group). Pause pressed when pi is NOT running (waiting mode / between tasks) degrades gracefully: SIGSTOP -> ESRCH no-op; the PauseGate (below) takes over semantics.
Residual risks: none identified in Process.kill itself (async-signal-safe); the only ordering requirement is CONT-before-TERM. Test coverage must include a subprocess test 'pause mid-run then q' proving prompt exit (no 3s stall).

Option B — defer-to-next-run only (no signals). Simpler, but 'p' while a task is running shows PAUSED while the agent keeps consuming model tokens/CPU until the task finishes — fails the user expectation 'pause the agent now' (TASK-67 description: 'pause that actually suspends the running run'). Pipe-backpressure pause (freeze letsdo's reading, pi blocks on pipe write) is slow/unreliable (pi blocks only at the next write; tokens keep burning until then) — rejected.

DECISION: Option A for mid-run + a shared thread-safe PauseGate flag for between-runs/waiting. Both states displayed via the existing TASK-42 PAUSED badge (renderer state_line already renders it); metrics.current_task distinguishes mid-run (non-nil, with elapsed) vs between-runs (nil) — the footer can hint 'p resume' vs 'p pause'.

Between-runs semantics: PauseGate (Mutex-guarded boolean, new small class) is shared by the input thread (toggle on 'p') and the loop driver. Letsdo::Loop stays generic — the gate is polled in AgentLoop#wrapped_run BEFORE run_started: while gate paused -> sleeper.call(0.2) (interruptible by Letsdo::Stopped raise). Waiting mode already idle; a paused gate there just shows PAUSED; when tasks arrive, the next run waits for resume. Mid-run 'p' additionally calls PiRunner#pause (SIGSTOP); resume 'p' calls PiRunner#resume (SIGCONT) plus clears the gate. Order: set gate first, then SIGSTOP (SIGSTOP on an already-exited group is ESRCH no-op; the gate keeps the semantics).
---

author: @analyst
created: 2026-09-04 08:25
---
NON-TUI STORY + RECONCILIATION WITH TASK-42 + AFFECTED COMPONENTS:

Non-TUI control (plain line-stream mode, stdout not a TTY / TERM=dumb / CI):
* STOP: SIGINT/SIGTERM already work and stay the same (trap -> pi group TERM + raise Letsdo::Stopped -> exit 0). No change.
* PAUSE/RESUME + QUIET: new stdin line commands 'p' and 'q' (Enter-terminated), ACTIVE ONLY when stdin is a TTY: a small control reader thread (same Thread.main.raise pattern as the TUI input thread) reads lines: 'p' toggles PauseGate + runner pause/resume (identical semantics to TUI 'p'), 'q' = Thread.main.raise(Letsdo::Stopped) = identical to a stop signal. Non-TTY stdin (pipes, /dev/null, CI): control unavailable by design — stop remains signal-only; documented (letsdo never reads stdin today, so no conflict with piped data; TTY-gating avoids stealing bytes from a hypothetical stdin pipe user).
* SIGTSTP/Ctrl-Z: REJECTED for pause — job-control clash: letsdo must stop itself to satisfy the shell's job-state bookkeeping, and pi lives in its own group, so default Ctrl-Z stops only letsdo (pi keeps burning tokens until pipe backpressure) with undefined timing. Trapping SIGTSTP to freeze only pi leaves the shell waiting on a never-stopped job. Documented as shell-level job control only.
* SIGHUP: recommended small hardening — trap SIGHUP like SIGINT/SIGTERM in AgentLoop (terminal closed -> prompt cleanup of pi instead of orphaned-group lingering).

RECONCILIATION with TASK-42 (in progress): TASK-42's 'p' = display freeze only (log keeps buffering, agent keeps running). TASK-67 replaces the semantic: 'p' = display freeze AND suspension (SIGSTOP/PauseGate). The TASK-42 renderer/log-buffering work stays as-is — only the session 'p' handler and the header state texts change (PAUSED stays the badge; footer hint becomes 'p' resume/pause context-aware). Metrics/renderer untouched otherwise. Control lives at AgentLoop/TUI level; Letsdo::Loop gains nothing (its generic interface already injects everything). PiRunner gains two public methods (#pause/#resume) + one line in #terminate (CONT before TERM) — no Loop coupling.

Wiring (CLI, run_agent_tui): PauseGate created in CLI, passed to Session (toggle + runner pause/resume via agent.runner — Agent#runner attr_reader already exists from TASK-39) and to AgentLoop (pause_gate param, default no-op -> plain mode byte-identical). Plain mode gets the control reader only when stdin.tty?; default off in tests/CI.

AFFECTED COMPONENTS: lib/letsdo/pi_runner.rb (pause/resume, CONT-before-TERM), lib/letsdo/agent_loop.rb (pause_gate param + SIGHUP trap), lib/letsdo/tui/session.rb ('p' handler + quit @stop ordering + footer hint), new lib/letsdo/control.rb (PauseGate + plain-mode stdin ControlReader), lib/letsdo/cli.rb (wiring), tests (pi_runner, agent_loop subprocess incl. quit-while-paused, session keys, control reader), README (keys + non-TTY control).
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Agent-control spike complete: designed and handed to @developer. (1) Control model — both stop triggers ('q'/Ctrl-C TUI key via Thread.main.raise; SIGINT/SIGTERM via raise-in-trap) already converge on ONE teardown path (Letsdo::Stopped + PiRunner terminate/reap + terminal restore + exit 0), verified against pi_runner.rb/agent_loop.rb/tui/session.rb/errors.rb; one small gap (quit should set @stop first) folded into TASK-74. (2) Pause — recommended SIGSTOP/SIGCONT to the pi group for true mid-run suspension, evaluated signal-safe on CRuby 4.0 (no letsdo trap involved; child group frozen out-of-band; reader stays blocked on the pipe) with the mandatory CONT-before-TERM fix in terminate() so quit-while-paused does not stall; between-runs/waiting pause via a shared Control::PauseGate polled by AgentLoop#wrapped_run (Letsdo::Loop untouched). (3) Non-TUI — stdin line commands 'p'/'q' on TTY stdin with identical semantics; signal-only otherwise; SIGTSTP rejected (job-control trap clash); SIGHUP hardening included. Developer tasks created: TASK-73 (PiRunner pause/resume + CONT-before-TERM), TASK-74 (PauseGate + AgentLoop gate + TUI 'p' suspension + quit-while-paused + SIGHUP, dep 42/73), TASK-75 (plain-mode stdin control, dep 74) — all @developer with testable ACs, single-PR sized. Verified: 4/4 ACs with evidence in comments + validation note; no code changed by the spike (only backlog metadata).
<!-- SECTION:FINAL_SUMMARY:END -->
