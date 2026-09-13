---
id: TASK-93
title: 'letsdo: add doctor hint to the backlog-unavailable wait message'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-13 13:28'
labels: []
dependencies:
  - TASK-71
priority: medium
type: enhancement
ordinal: 82000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When the first provider call of a run returns nil (the backlog is unreadable), the loop prints "letsdo: backlog unavailable, retrying in Ns" forever with no hint about why. After TASK-71 (`letsdo doctor`), extend that line ONCE per run to add a hint: "letsdo: backlog unavailable, retrying in Ns - run `letsdo doctor` to diagnose". Later nils in the same run keep today's short line.

Scope is the message text only (AgentLoopTasks#provider_unavailable). No doctor behavior here.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The first provider-nil in a run prints the message with the doctor hint (exact wording asserted in a test)
- [ ] #2 Subsequent provider-nils in the same run print the short line without the hint
- [ ] #3 Existing loop/cli tests updated; a new test covers the once-per-run hint; rake test 0 failures; all texts English (TASK-35)
<!-- AC:END -->
