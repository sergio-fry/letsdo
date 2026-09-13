---
id: TASK-95
title: 'Deterministic task selection: priority-sorted, ready-only provider batch'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-13 16:22'
labels: []
dependencies: []
documentation:
  - docs/task-selection.md
priority: medium
type: enhancement
ordinal: 84000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Today the provider (Letsdo::Providers::Backlog) requests open tasks with no ordering or readiness filter, and drops the fields a selector would need. The order letsdo reads therefore does not govern the task the agent works: the agent re-queries the backlog inside its prompt, and letsdo's retry accounting keys on the batch element rather than the task actually worked. Scope A of the analysis in docs/task-selection.md. Outcome: the batch letsdo hands to the loop is the authoritative runnable order, so the common divergence between what letsdo reads and what the agent picks disappears.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Providers::Backlog requests open, runnable tasks in priority order: the backlog command includes readiness filtering and priority sorting
- [ ] #2 Blocked tasks (dependencies not done) are not offered to the loop
- [ ] #3 Normalized Task keeps the fields selection needs beyond id/title/status/priority/assignees (at least ordinal; ideally also type/labels/milestone), and a growing backlog JSON schema still cannot crash the adapter
- [ ] #4 The batch order is deterministic and stable for equal-priority tasks (In Progress first, then priority High>Medium>Low, then ordinal ascending, then id ascending) with a unit test for the equal-priority tie-break
- [ ] #5 Letsdo::Loop stays generic: no prompt or Letsdo::Agent contract change in this task
- [ ] #6 Tests cover the provider command line, readiness filtering, field normalization and the tie-break; rake test is green
- [ ] #7 docs/task-selection.md and README are updated if the behavior it describes changes
<!-- AC:END -->
