---
id: TASK-52
title: >-
  Spike: AI backend adapter (pi today; Claude Code / Cursor as future backends)
  — decouple business logic
status: To Do
assignee:
  - '@analyst'
created_date: '2026-09-04 07:11'
labels: []
dependencies:
  - TASK-50
type: spike
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design the adapter seam between letsdo business logic and the AI/agent backend (per user request: instead of pi one day Cursor console / Claude could be used — business logic must not hard-depend on a single product).

Current state: Letsdo::Agent builds PiRunner directly — it hardcodes 'pi --mode json <flags> <prompt>', parses pi-specific events (message_update/text_delta, toolcall_start, tool_execution_start/end, agent_end), OutputStreamer consumes those events, termination goes through process-group kill (PiRunner#terminate). Env knobs today: LETSDO_PI_COMMAND, LETSDO_PI_FLAGS (=> backend-specific already leak into CLI).

Design goal: define a backend interface — run(prompt) or run(task) → normalized streaming events + exit code; terminate/stop support; backend selection (env knob e.g. LETSDO_BACKEND=pi|claude|cursor, default pi; overridable for tests); map the pi protocol onto normalized events so OutputStreamer/business layer stays backend-agnostic; keep LETSDO_DEBUG semantics. Roadmap for a real second backend (Claude Code / Cursor CLI) must be described as developer tasks, NOT implemented here.

Coordinate with TASK-50 (target layout) and TASK-52 (same interface philosophy for the task provider side). Deliverable: design documented in task comments + developer tasks (@developer) with ACs. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Normalized backend protocol specified: event types, exit-code semantics, termination/stop, debugging — independent of pi vocabulary
- [ ] #2 How pi maps onto the protocol (PiRunner → pi_backend adapter, fake backend for tests replacing fake_pi approach evaluated)
- [ ] #3 Backend registry/selection designed (env-driven default pi, injectable for tests); what stays in business logic vs adapter is explicit (Agent/Loop/OutputStreamer/CLI deltas)
- [ ] #4 Adding a second real backend (Claude Code / Cursor) described as developer tasks with ACs — not implemented
- [ ] #5 Spike leaves the code untouched (no commits, no file edits)
<!-- AC:END -->
