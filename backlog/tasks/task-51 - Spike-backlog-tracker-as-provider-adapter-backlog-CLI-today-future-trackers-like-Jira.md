---
id: TASK-51
title: >-
  Spike: backlog tracker as provider adapter (backlog CLI today; future trackers
  like Jira)
status: To Do
assignee:
  - '@analyst'
created_date: '2026-09-04 07:11'
labels: []
dependencies:
  - TASK-50
type: spike
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design the adapter seam between the orchestrator and the task/backlog tracker (per user request: the backlog tracker should also be an adapter — Backlog.md via CLI today, other trackers possible later; there IS specificity, not fully generic yet).

Current state: Letsdo::BacklogTasks shells out via Open3 to 'backlog task list --assignee <handle> --exclude-status Done --json' (LETSDO_BACKLOG_COMMAND), returns Array<Hash> of open tasks or nil when the backlog is unreadable (CLI missing/failed/bad JSON). Letsdo::Loop already consumes a generic callable → Array (empty = none, nil = unreadable → pause+retry) — a good basis. Coupling: provider is hardwired to the backlog CLI and its JSON schema ('tasks' key, task fields).

Design goal: a TaskProvider interface (e.g. open_tasks(assignee) → normalized tasks | nil, preserving the empty-vs-unreadable semantics Loop relies on), a normalized task shape (id, title/status/assignee fields), BacklogTasks reframed as the backlog adapter over that interface, provider selection (env knob e.g. LETSDO_PROVIDER=backlog, default; injectable for tests). Future trackers (Jira/Linear/GitLab issues) described as developer tasks, NOT implemented here.

Coordinate with TASK-50 (target layout) and TASK-51 (same interface philosophy, adapter conventions). Deliverable: design documented in task comments + developer tasks (@developer) with ACs. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 TaskProvider interface specified, explicitly preserving empty-array (no tasks) vs nil (unreadable → retry) semantics used by Letsdo::Loop
- [ ] #2 Normalized task shape defined; BacklogTasks mapped onto it as the backlog adapter (JSON schema differences handled inside the adapter)
- [ ] #3 Provider registry/selection designed (env-driven, default backlog, injectable for tests); Loop/AgentLoop require no protocol change or the minimal delta is spelled out
- [ ] #4 Future tracker adapters (Jira/Linear/GitLab) described as developer tasks with ACs — not implemented
- [ ] #5 Spike leaves the code untouched (no commits, no file edits)
<!-- AC:END -->
