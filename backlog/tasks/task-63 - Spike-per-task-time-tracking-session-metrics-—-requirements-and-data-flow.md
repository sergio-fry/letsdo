---
id: TASK-63
title: 'Spike: per-task time tracking + session metrics — requirements and data flow'
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 08:01'
updated_date: '2026-09-04 08:11'
labels: []
dependencies:
  - TASK-42
type: spike
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Gather requirements and design time tracking + session reporting for the letsdo orchestrator (per user request — analysis task). The user wants the product to show: how many tasks are done in the current session, how many remain, time spent on the session, elapsed time per task, and similar useful metrics — both live and summarized.

Context: TASK-42's TUI already puts live metrics in the header (session timer, done-in-session counter, tasks remaining, current-task elapsed) via a metrics facade fed by the loop driver. This spike should define the FULL requirements beyond the header: what a user wants to see, where the data lives, and how it is surfaced and persisted — e.g. per-task elapsed recorded into the task on completion (backlog comment/notes), a session report on stop ('3 tasks done in 12m, 1 failed'), optional log/JSON output for non-TTY runs. Data sources: run start/end hooks at driver level (Loop/AgentLoop), monotonic clocks, latest provider task count.

Design constraints: Letsdo::Loop stays generic/injectable (metrics facade wired at CLI/AgentLoop level, like TASK-42 planned); one-agent-one-task contract unchanged; non-TTY output stays plain. Do this design NOW while TASK-42 metrics hooks are being built — retrofitting later is expensive. Deliverable: requirements + UX/data-flow spec in comments + developer tasks (@developer) with ACs. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Requirements list documented from the user's asks: tasks done in session, tasks remaining, total session time, time per task, failed count, and design decisions on what else is useful
- [x] #2 Data flow designed: who computes what (run hooks, monotonic timing, provider counts), where metrics are aggregated, how it plugs into TASK-42's metrics facade without touching Letsdo::Loop internals
- [x] #3 Persistence/output formats defined: per-task elapsed in the task record, session summary line(s) at stop, non-TTY variant, optional structured log — with rationale
- [x] #4 Developer task(s) created via backlog CLI (@developer) with ACs, sized for single-PR; spike leaves code untouched
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Study current state: Letsdo::Loop/AgentLoop driver (metrics: callbacks exist — provider_result/run_started/run_finished), Tui::Metrics facade (TASK-42, live header), OutputStreamer clock injection, backlog CLI comment support for task write-back.
2. Requirements list from the user's asks (done/left/session-time/per-task-elapsed/failed) + extra useful metrics.
3. Data flow design: mode-independent Letsdo::SessionRecorder fed by the same AgentLoop events; outcome = exit code (run_finished(code)); final provider snapshot diff for 'left open'; waiting = session total - run sum; fanout in TUI mode; no Letsdo::Loop changes.
4. Persistence/output: session summary line(s) at stop (plain stderr + TUI post-restore), optional JSONL metrics file (env-gated), task-record write-back (backlog comment) as design decision — opt-in/deferred with rationale.
5. Create @developer task(s) with ACs (single-PR sized), verify, finalize.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification: design recorded in TASK-63 comments C1 (requirements), C2 (data flow), C3 (persistence/output + write-back decision). Developer deliverables created via CLI: TASK-69 (base: SessionRecorder + stop summary + JSONL, deps TASK-42, 6 ACs) and TASK-70 (opt-in backlog write-back LETSDO_TASK_TIME_COMMENT, deps TASK-69, 6 ACs) — both assigned @developer. Code untouched by this spike: lib/ and test/ changes in the working tree are the developer's in-flight TASK-42 WIP (confirmed identical to the pre-run git status); my footprint is backlog files only (task-63, task-69, task-70).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-04 08:09
---
Analysis C1 — Requirements (AC #1).

User asks (from the request; live side already covered by TASK-42): tasks done in the current session, tasks remaining, time spent on the session, elapsed time per task, and similar useful metrics — live and summarized.

Scope split:
- LIVE (TASK-42, already designed/in flight): Tui::Metrics header — done-in-session, left, session timer, current-task elapsed, waiting indicator. Not repeated here.
- THIS SPIKE (summarized + persistent): per-run duration and outcome, session summary at stop, optional structured log, task-record write-back decision.

Expanded metric list (design decisions):
1. done — runs with exit code 0 (one run = one task contract; exit 0 = completed).
2. failed — runs with exit code != 0 (consistent with TASK-68's failure classification for retry).
3. interrupted — run started but never finished (killed by stop/q): recorded, counted as neither done nor failed.
4. left — latest provider open-task count (final snapshot at stop; nil = backlog unreadable).
5. session total — monotonic from CLI run start.
6. active — sum of run durations.
7. waiting — session total − active (derived; includes poll/backlog overhead — documented approximation; no Loop/sleeper changes needed).
8. avg per-task — mean duration over done runs (planning aid).
9. per-task list — task id + duration + outcome in the stop summary, capped at 10 lines.

Out of scope (not requirements, noted for future): tool-level time aggregation (streamer lines already carry per-tool durations), per-hour throughput/velocity, cross-session history dashboards (the JSONL log below makes these possible later).
---

author: @analyst
created: 2026-09-04 08:10
---
Analysis C2 — Data flow design (AC #2).

Sources (all at loop-driver level, same pattern as TASK-42): Letsdo::AgentLoop already emits provider_result(count|nil), run_started(task_label), run_finished (in an ensure). Monotonic clock: Process.clock_gettime(CLOCK_MONOTONIC). Letsdo::Loop stays generic and untouched.

New component: Letsdo::SessionRecorder (lib/letsdo/session_recorder.rb) — mode-independent (no tui/ deps), thread-safe (Mutex; snapshots read from the TUI input thread), injectable clocks (monotonic for durations, wall for log timestamps — same injection pattern as Tui::Metrics/OutputStreamer).

Events (same callback interface as Tui::Metrics, one change):
- provider_result(count) → latest left count (nil = unreadable).
- run_started(task_id) → open run record {task_id, started_mono}.
- run_finished(exit_code) → close the record {elapsed_s, exit_code}; outcome exit==0 → :done, else :failed.
- summary → totals + per-run list; a record still open at summary time → :interrupted.
- summary_line → text for stderr.

Interface change (small, coordinated with in-flight TASK-42): AgentLoop#wrapped_run's ensure calls @metrics&.run_finished(code) (today: no argument). Tui::Metrics#run_finished(exit_code = nil) ignores the argument — header behavior unchanged. The agent_loop_test stub MetricsRecorder#run_finished gains the same optional param. This is the ONLY touch to AgentLoop; lib/letsdo/loop.rb stays diff-free.

Wiring (both modes):
- plain: CLI passes metrics: recorder — summary works without any TUI.
- TUI: CLI passes metrics: Letsdo::Metrics::Fanout.new(recorder, tui_metrics) — new tiny class (lib/letsdo/metrics/fanout.rb) forwarding provider_result/run_started/run_finished to each observer, so the header keeps working.
- TUI 'r' refresh: CLI wraps the session refresh proc to also feed recorder.provider_result (fresh 'left' for the stop summary).
- Clocks: one shared monotonic clock created in CLI, injected into the recorder AND Tui::Metrics (same session base time); tests inject fakes.

Nothing else changes: PiRunner event loop, OutputStreamer, PromptStore untouched.
---

author: @analyst
created: 2026-09-04 08:10
---
Analysis C3 — Persistence / output formats (AC #3).

1. Session summary at stop (both modes): CLI prints recorder.summary_line to REAL stderr after the loop/session ends — plain mode after AgentLoop's 'letsdo: stopped'; TUI mode after Tui::Session#run returns (terminal already restored, so the text is visible on exit; AgentLoop's own 'stopped' line still goes to the log buffer in TUI mode — unchanged). Format:
   letsdo: session: 3 done, 1 failed, 0 interrupted, 2 left open, 12m 34s (9m 10s in runs, 3m 24s waiting, avg 3m 3s)
   letsdo:   TASK-42 done in 4m 12s
   ... up to 10 per-run lines, then 'letsdo:   … and 13 more'

2. Structured log: env LETSDO_METRICS_FILE=<path> (default: none — no file, no behavior change). CLI opens the path in append mode; the recorder writes and flushes one JSON line per event (crash-safe):
   {"event":"session_start","agent":"developer","handle":"@developer","ts":"2026-09-04T08:00:00Z"}
   {"event":"run_finished","task":"TASK-42","exit":0,"outcome":"done","elapsed_s":252.3,"ts":"..."}
   {"event":"session_stop","agent":"developer","ts":"...","done":3,"failed":1,"interrupted":0,"left":2,"session_s":754.0,"runs_s":550.2}
   Wall-clock ts: ISO8601 UTC; durations from the injectable monotonic clock.

3. Per-task elapsed in the task record (backlog comment write-back): DECISION — opt-in, batched at stop, implemented as a separate smaller dev task (default off; env LETSDO_TASK_TIME_COMMENT=1). Design: at stop, for exit-0 runs whose task id is ABSENT from a fresh final provider snapshot (re-query once at stop; skip still-open tasks — 'completed' would be wrong), CLI runs the configured backlog command (LETSDO_BACKLOG_COMMAND, cwd = root): backlog task edit <id> --comment 'letsdo: completed in 4m 12s' --comment-author @letsdo. Write failures are non-fatal: warn once per task, summary notes 'N comments not written'.
   Rationale: (a) the recorder stays provider-agnostic — the CLI owns provider I/O; (b) batched at stop, not per-run: no race with the agent's closing edit (file-based backlog CLI has no locks) and no extra subprocess per completed run; (c) opt-in because it mutates task files.

4. Non-TTY variant: identical recorder; the same summary line(s) go to stderr; no header metrics; JSONL unaffected. Non-TTY output stays byte-identical to today except for the added summary line(s) after 'letsdo: stopped'.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
TASK-63 spike done: per-task time tracking + session metrics requirements and data flow designed and handed to @developer. Deliverables: (1) requirements list + design decisions (TASK-63 comments C1-C3, English): live metrics stay in TASK-42's header, this spike adds per-run durations with exit-code outcomes (done/failed/interrupted), stop summary in plain+TUI, optional JSONL log (LETSDO_METRICS_FILE), and an opt-in batched-at-stop backlog comment write-back (LETSDO_TASK_TIME_COMMENT); (2) new Letsdo::SessionRecorder spec (mode-independent, same AgentLoop events, only driver touch = run_finished(code) signature) — Letsdo::Loop stays generic; (3) verified: TASK-69 (base impl) and TASK-70 (write-back) exist, assigned @developer, 6 ACs each, single-PR sized, deps TASK-42/TASK-69; spike left no code changes (git status lib/ identical to pre-run; backlog files only from me).
<!-- SECTION:FINAL_SUMMARY:END -->
