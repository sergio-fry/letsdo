---
id: TASK-57
title: >-
  Roadmap: second task provider (Jira first) over the TaskProvider interface —
  not scheduled
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:37'
labels: []
dependencies:
  - TASK-56
references:
  - TASK-51
type: feature
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Roadmap placeholder from the TASK-51 spike: future trackers (Jira/Linear/GitLab) are NOT implemented now. This task pins the acceptance contract a second tracker implementation must satisfy once one is actually needed; at scheduling time the implementer copies these ACs into a fresh task. Backbone: an adapter class in lib/letsdo/providers/ implementing the TaskProvider contract (#call -> Array<Letsdo::Providers::Task> | nil, empty vs nil semantics preserved), tracker schema mapped inside the adapter, provider registered in the Builder registry under its LETSDO_PROVIDER value, fake-CLI tests mirroring the fake_backlog scenarios.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Documents the landing path for any tracker: adapter in lib/letsdo/providers/ (e.g. jira.rb) implementing #call -> Array<Letsdo::Providers::Task> | nil (empty = no tasks, nil = tracker unreadable -> retry); tracker JSON/API schema mapped onto Letsdo::Providers::Task inside the adapter; registration in the Builder provider registry; fake CLI fixture + provider tests mirroring fake_backlog (open/empty/fail/malformed/argv)
- [ ] #2 Jira specified as the first concrete case: JQL for the assignee excluding done (e.g. assignee = <handle> AND status not in (Done)), field mapping (key -> id, summary -> title, status/priority/assignees mapped), auth and CLI availability notes, and nil semantics for auth failure / API outage (-> retry like today's unreadable backlog)
- [ ] #3 Linear and GitLab listed as alternative candidates with their mapping surface (Linear: identifier/title/state; GitLab: IID/title/state/labels) — candidates only, not scoped or specified as tasks yet
- [ ] #4 Explicit roadmap item: nothing is implemented or scheduled with this task; its ACs become the acceptance checklist of the future implementation task at scheduling time; all texts in English (TASK-35)
<!-- AC:END -->
