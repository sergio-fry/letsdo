---
id: TASK-69
title: 'Session metrics: Letsdo::SessionRecorder, stop summary, JSONL metrics file'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:10'
updated_date: '2026-09-04 10:27'
labels: []
dependencies:
  - TASK-42
priority: medium
type: enhancement
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the session-metrics design from TASK-63 (design comments C1-C3; read them first). Adds a mode-independent Letsdo::SessionRecorder fed by the same AgentLoop events as the TUI header: per-run durations with exit-code outcomes (done/failed/interrupted), a session summary printed at stop (plain stderr + TUI after terminal restore), and an optional append-only JSONL metrics file (LETSDO_METRICS_FILE). Letsdo::Loop stays generic and untouched; the only driver touch is AgentLoop forwarding the run exit code (metrics.run_finished(code)) — Tui::Metrics#run_finished accepts the optional argument and ignores it. Wiring: plain mode passes the recorder as metrics:; TUI mode passes Letsdo::Metrics::Fanout.new(recorder, tui_metrics) so the header keeps working. Affected components: new lib/letsdo/session_recorder.rb, new lib/letsdo/metrics/fanout.rb, lib/letsdo/agent_loop.rb, lib/letsdo/tui/metrics.rb (signature only), lib/letsdo/cli.rb (wiring + summary print + metrics file), test/agent_loop_test.rb stub, new session_recorder/fanout/cli tests, README (LETSDO_METRICS_FILE + stop summary). Coordination: TASK-42 is in flight and touches the same files — land the run_finished signature together with this change; do not rework Tui::Session.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Letsdo::SessionRecorder (lib/letsdo/session_recorder.rb) is mode-independent (no tui/ deps), thread-safe, with injectable monotonic + wall clocks: run records {task_id, started_mono, finished_mono, elapsed_s, exit_code}; provider_result(count) tracks latest left (nil = unreadable); outcome exit==0 → done, exit!=0 → failed; a record still open when summary is requested → interrupted; summary aggregates done/failed/interrupted/left/session_s/active_s (= sum of runs)/waiting_s (= session − active, documented approximation)/avg over done runs; summary_line prints the TASK-63 C3 format with ≤10 per-run lines then '… and N more'
- [ ] #2 AgentLoop passes the exit code to metrics: wrapped_run's ensure calls @metrics&.run_finished(code); Tui::Metrics#run_finished(exit_code = nil) ignores the argument (header behavior unchanged); the agent_loop_test stub MetricsRecorder#run_finished gains the optional param; lib/letsdo/loop.rb has no diff
- [ ] #3 CLI wires the recorder in both modes: plain — metrics: recorder; TUI — metrics: Letsdo::Metrics::Fanout.new(recorder, tui_metrics) (lib/letsdo/metrics/fanout.rb forwards provider_result/run_started/run_finished to each observer); the TUI 'r' refresh proc also feeds recorder.provider_result. After the loop/session ends, CLI prints recorder.summary_line to real stderr — plain after 'letsdo: stopped', TUI after terminal restore
- [ ] #4 LETSDO_METRICS_FILE: when set, CLI opens the path in append mode and hands the IO to the recorder; the recorder writes one JSON line per event (session_start / run_finished {task, exit, outcome, elapsed_s, ts} / session_stop) with ISO8601 UTC wall timestamps and monotonic durations, flushing per line; env unset → no file, no behavior change; invalid/unwritable path → stderr warning, run continues without the file
- [ ] #5 Tests: new session_recorder_test.rb (fake clocks — durations, done/failed/interrupted classification, left + nil, waiting derivation, summary format + cap, JSONL via StringIO), fanout unit test, agent_loop_test (exit code forwarded), cli_test updated (summary line present in plain output; LETSDO_METRICS_FILE via tempfile), tui_metrics_test semantics unchanged; no real TTY anywhere; rake test 0 failures; rubocop 0 offenses
- [ ] #6 All texts English (TASK-35); plain non-TTY output byte-identical to today except the added summary line(s) after 'letsdo: stopped'; README documents LETSDO_METRICS_FILE and the stop summary
<!-- AC:END -->
