---
id: TASK-62
title: 'Spike: loop reliability (retry/backoff, failing-task handling, crash recovery)'
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 08:01'
updated_date: '2026-09-04 08:05'
labels: []
dependencies:
  - TASK-45
type: spike
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design reliability improvements for the orchestrator loop (per user request: 'reliability of the loop needs strengthening'). Today Letsdo::Loop/AgentLoop on a non-zero agent exit just logs 'exited with code N' and continues — a persistently failing task causes an immediate tight loop of agent runs (no backoff); a clean SIGINT/SIGTERM stop is the only exit; a task left In Progress after a crash is picked up next run (by agent prompt rule), but there is no explicit policy for it.

Design topics: (1) retry/backoff — policy for repeated failures of the same task/agent (e.g. exponential backoff, skip-after-N with a recorded note, give up semantics); (2) failure classification — what non-zero exit codes mean (pi missing, agent error, task broken) and how each should be handled; (3) crash recovery — formal rule for tasks stuck In Progress or half-done (restart, reassign, or leave for the analyst), what the agent prompt says today; (4) stopping semantics — guarantee a stop happens promptly (already interruptible) and a started run is always terminated; (5) alignment with TASK-45 (filesystem-wake waiting) so waiting never spins. Keep Letsdo::Loop generic — policy lives at AgentLoop level or in a small policy object. Deliverable: requirements + design in comments + developer tasks (@developer) with ACs. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Failure taxonomy: non-zero exit causes (missing pi/backend, agent error, task-level breakage) mapped to concrete loop behavior
- [x] #2 Retry/backoff policy designed: rules for same-task and same-agent repeated failures, limits, recorded outcomes, interaction with agent 'one task per run' contract
- [x] #3 Crash-recovery policy formalized: In Progress / half-done tasks handling, who decides (agent prompt vs loop), and what stays out of scope
- [x] #4 Developer task(s) created via backlog CLI (@developer) with ACs, sized for single-PR; spike leaves code untouched
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify current behavior in code (Loop/AgentLoop/PiRunner/CLI prompts) — done: tight-loop on failure is real (provider re-returns the same open task; no backoff; spawn-ENOENT crashes letsdo uncaught).
2. Define failure taxonomy: (a) provider unreadable → pause+retry (unchanged); (b) backend spawn error → fail fast exit 2; (c) non-zero exit OR exit-0-but-still-open → per-task retry/backoff with give-up; (d) signal-killed run 128+n → same as (c).
3. Design retry policy object (Letsdo::RetryPolicy): per-task state, exponential backoff via cooldown filtering, max failures per session, stderr notes; Letsdo::Loop stays generic; policy wired in AgentLoop.
4. Formalize crash-recovery policy: In Progress tasks intentionally re-run by the agent prompt rule 0 ('if a task is already in progress'); loop never resets other agents' In Progress tasks; stuck-detection/reassignment out of scope.
5. Stopping semantics review: existing terminate_now+raise+grace-KILL path already guarantees termination; keep, add regression ACs.
6. TASK-45 alignment: policy exposes earliest-cooldown so fs-wake wait can be bounded; wake re-check runs the same filter (no spin).
7. Create @developer task with ACs (single PR); finalize TASK-62; commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
REQUIREMENTS (consolidated, source of truth for the developer task):
R1 letsdo must never tight-loop on a failing task: same task, at most LETSDO_MAX_RETRIES (default 3) consecutive failed runs per session, spaced by exponential backoff (LETSDO_RETRY_BASE default = wait_seconds, cap LETSDO_RETRY_CAP default 300s).
R2 Failure signal = non-zero exit OR (exit 0 and task still open on next poll). Task gone from provider = success (clear retry state).
R3 Missing/unexecutable backend binary: controlled fail-fast exit 2 with clear message (no Ruby backtrace). New Letsdo::BackendUnavailableError in lib/letsdo/errors.rb.
R4 Letsdo::Loop untouched/generic; policy in small pure object lib/letsdo/retry_policy.rb (injectable clock), wired in AgentLoop; CLI parses the 3 env knobs with defaults (pattern of wait_seconds in cli.rb).
R5 After give-up the task stays open, stderr/TUI log records the outcome; fresh session resets failure state.
R6 Crash recovery stays agent-prompt-owned: In Progress tasks are re-run by rule 0; loop never resets tasks; no auto-reassign/stuck-detection in this change (TASK-63/67 overlap).
R7 Stop path unchanged: cooldown rides the interruptible sleeper; regression tests for stop-during-backoff and started-run-always-terminated.
R8 README: brief section on failure handling + the 3 env knobs.
AFFECTED COMPONENTS: lib/letsdo/retry_policy.rb (new), lib/letsdo/agent_loop.rb (wiring), lib/letsdo/pi_runner.rb + lib/letsdo/agent.rb (spawn-error -> BackendUnavailableError), lib/letsdo/errors.rb, lib/letsdo/cli.rb (env knobs), tests, README.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-04 08:04
---
CURRENT BEHAVIOR AUDIT (verified in code, commit 3fd826d + TASK-42 WIP):
- Letsdo::Loop (lib/letsdo/loop.rb) is generic and correct: provider -> run each task once -> re-poll; nil/empty -> sleep wait_seconds; stops only via #stop (signal-driven).
- Tight loop is real, at AgentLoop level (lib/letsdo/agent_loop.rb#wrapped_run): a non-zero exit logs 'letsdo: <name> exited with code N' and the loop immediately re-polls; the failed task is still open in backlog (BacklogTasks excludes only Done, In Progress included), so it is re-run at once — no backoff, unbounded repeated runs of the same task.
- Missing backend binary is not handled at all: Process.spawn in PiRunner#run (lib/letsdo/pi_runner.rb:79) raises Errno::ENOENT uncaught -> letsdo dies with a Ruby backtrace, not a controlled error.
- Crash recovery already works implicitly: a task left In Progress after a crash is listed by the provider and the agent prompt selection rule 0 ('if a task is already in progress') makes the agent re-take it; notes/comments in the backlog survive, so re-running is safe (backlog is the source of truth, no local state).
- Stop path is solid: SIGINT/SIGTERM -> on_signal -> terminate_now (TERM to pi group, trap-safe) + raise Letsdo::Stopped -> PiRunner rescue terminates with TERM->KILL grace 3s and reaps -> loop unwinds -> exit 0 (both plain and TUI modes; TUI q raises on Thread.main the same way).
- Provider-command child on stop: Open3.capture3 in BacklogTasks is interrupted by the raise; the short-lived backlog CLI child is not explicitly terminated — minor, acceptable (it exits on its own), noting as a known gap.
- Test seams exist for everything needed: fake provider/run_one + throw-sleeper in test/agent_loop_test.rb; fake command + StringIO in pi_runner_test.rb; injectable clock pattern already used in tui_metrics_test.rb.
---

author: @analyst
created: 2026-09-04 08:04
---
DESIGN 1/3 — FAILURE TAXONOMY (what a bad outcome means and how to handle it):
Classify by where the break happens, not by the code alone:
(a) provider unreadable (BacklogTasks#call returns nil) — infra pause: keep current 'retrying in Xs' behavior, never run the agent. Unchanged.
(b) backend spawn error (errno from Process.spawn: ENOENT pi missing, EACCES) — fatal configuration error, NOT a loop problem: catch in PiRunner/Agent, raise Letsdo::BackendUnavailableError (new, in lib/letsdo/errors.rb), fail fast exit 2 with a clear message instead of a Ruby backtrace. Rationale: a missing binary cannot self-heal; retrying it inside the loop is noise.
(c) agent/task-level failure: pi ran and exited non-zero — one run failed. Also signal-killed pi (exit_code 128+termsig, e.g. SIGSEGV) is the same class. Handle: per-task retry with backoff + give-up (Design 2).
(d) exit 0 but the task is still open on the NEXT provider poll — the run completed but did not close the task (agent ended early, completion edit failed). This is the most common real-world 'soft failure' and today is invisible. Count it exactly like (c): the loop can see it by comparing what it ran last batch with the fresh provider result — no backend changes needed.
Rules of thumb: exit code alone is not the failure signal — 'task still open after a run' is; a task disappearing from the provider list means success and clears the retry state.
---

author: @analyst
created: 2026-09-04 08:04
---
DESIGN 2/3 — RETRY/BACKOFF POLICY (new Letsdo::RetryPolicy, pure object):
Placement: Letsdo::Loop stays generic and untouched. All policy lives in a small pure policy object (lib/letsdo/retry_policy.rb) wired in AgentLoop — injectable clock (monotonic, as in Tui::Metrics) for deterministic tests.
State: per task key (task['id'], fallback task.to_s — reuse AgentLoop#task_label) -> { failures: n, cool_until: monotonic deadline }.
Signals: AgentLoop after each run records result; on the NEXT provider result it compares: task we ran that is still open -> record_failure(code); task gone -> record_success (clears state). Tasks filtered out by cooldown are not re-recorded (not attempted).
Backoff: cooldown filter — after failure n, the task is excluded from the attempt batch until now >= cool_until; cool_until = now + min(BASE * 2^(n-1), CAP). BASE = LETSDO_RETRY_BASE env (default = wait_seconds, i.e. 10s; 1st failure -> ~10s, 2nd -> ~20s, 3rd -> ~40s), CAP = LETSDO_RETRY_CAP env (default 300s). Spacing is naturally wait_seconds-granular because the loop re-polls every wait_seconds and the filter skips until the deadline — no extra sleeps inside the loop, signals stay interruptible (sleeper untouched).
Give-up: at MAX = LETSDO_MAX_RETRIES (default 3) consecutive failures the loop stops attempting the task for the rest of the session and logs 'letsdo: giving up on <TASK> after N failed runs — task stays open, next session will retry it'. The task is left open deliberately (outcome recorded in stderr/TUI log, visible to a human). State is in-memory only: a fresh letsdo session starts with zero failures, so a broken task yields instead of hammering, and a temporarily-failing task is retried next session. Env knobs are parsed in CLI and passed through; invalid values fall back to defaults (same pattern as wait_seconds in cli.rb).
Interaction with the agent 'one task per run' contract: unchanged — each retry is a separate agent run of the same task; no prompt changes needed. The TUI keeps current semantics (run_finished = attempt finished; backoff/give-up messages flow through the stderr -> LogBuffer path in TUI mode, no new metrics events required).
Optional (nice-to-have, NOT required in this spike): circuit breaker — N consecutive failures across DIFFERENT tasks suggests a systemic backend problem; log a visible warning. Not an AC; note only.
---

author: @analyst
created: 2026-09-04 08:04
---
DESIGN 3/3 — CRASH RECOVERY, STOPPING, TASK-45 ALIGNMENT:
Crash recovery (AC#3): the FORMAL policy is: 'a task left In Progress is intentionally re-run'. The backlog is the source of truth (notes/comments survive the crash), re-running is idempotent, and the agent prompt already encodes it (rule 0: if a task is already in progress, take it). Decision: the AGENT PROMPT stays the owner of this decision — the loop must NOT reset In Progress tasks, because a task In Progress for @developer may be genuinely being worked on by a concurrently running letsdo process; a loop-side reset would trample another agent's live work. Keep the current behavior, make it explicit in the developer task docs, and add a regression test (In Progress tasks appear in the provider list and are run).
Out of scope (explicitly, with rationale): automated stuck detection (In Progress for >X without changes), half-done state repair, auto-reassignment. These need task-state introspection (updated timestamps, edit history) that the TaskProvider interface does not expose today; they overlap with TASK-63 (time tracking/metrics spike) and TASK-67 (agent control) — deliberately not designed here to keep the change single-PR sized.
Stop semantics (AC#4): already meets the requirement — stop is prompt (raise-in-trap interrupts any wait), a started run is always terminated (TERM immediately, KILL after grace, reaped) and the loop exits 0; TASK-42 adds terminal restore in TUI mode. The developer task adds explicit regression ACs for 'started run always terminated' and 'stop during backoff cooldown is immediate' (cooldown rides the interruptible sleeper, so no new stop path is needed).
TASK-45 alignment (AC#5): two contract points for the fs-wake work: (1) the wake re-check must run the same RetryPolicy filter — a wake that only yields cooling-down/skipped tasks goes straight back to waiting (no spin; TASK-45 AC#2 extended with 'no runnable tasks' = 'no tasks'); (2) RetryPolicy exposes earliest_cooldown so the watcher wait can be bounded by min(wait deadline, next retry attempt) — retries stay responsive without polling. No coupling: RetryPolicy has no fs knowledge; TASK-45 consumes the deadline only if it wants to.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike complete (design only, zero code changes — verified: git diff on lib/letsdo/loop.rb is empty; all lib/ diffs are pre-existing TASK-42 WIP).

Evidence per AC:
- AC#1 (failure taxonomy): comment 'DESIGN 1/3' — four classes (provider unreadable / backend spawn error / non-zero or signal-killed run / exit-0-but-task-still-open), each with concrete loop behavior; spawn error -> new Letsdo::BackendUnavailableError + fail-fast exit 2.
- AC#2 (retry/backoff): comment 'DESIGN 2/3' + requirements note R1-R5 — pure Letsdo::RetryPolicy object (injectable clock, per-task state), cooldown-based exponential backoff (LETSDO_RETRY_BASE/CAP, defaults 10s/300s), give-up at LETSDO_MAX_RETRIES=3 per session, task left open, fresh-session reset; Letsdo::Loop untouched; knobs parsed in CLI like wait_seconds.
- AC#3 (crash recovery): comment 'DESIGN 3/3' — formal rule: In Progress tasks are intentionally re-run (agent-prompt-owned, rule 0); loop never resets tasks (concurrent-agent safety); stuck-detection/reassign out of scope (TASK-63/67 overlap).
- AC#4 (deliverable): TASK-68 created via backlog CLI, assignee @developer, type enhancement, 8 testable ACs, single-PR sized, --dep TASK-62; spike changed no code.

Also covered: stop semantics audit (TERM->KILL grace path already guarantees termination; regression ACs in TASK-68) and TASK-45 alignment (wake re-check runs the same RetryPolicy filter — no spin; policy exposes earliest_cooldown for bounded watcher waits).
<!-- SECTION:FINAL_SUMMARY:END -->
