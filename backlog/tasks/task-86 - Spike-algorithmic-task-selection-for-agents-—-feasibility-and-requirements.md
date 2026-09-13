---
id: TASK-86
title: 'Spike: algorithmic task selection for agents — feasibility and requirements'
status: To Do
assignee: []
created_date: '2026-09-10 07:27'
updated_date: '2026-09-13 10:33'
labels: []
dependencies: []
priority: medium
type: spike
ordinal: 75000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Investigate whether the next task an agent should pick up can be selected programmatically and algorithmically.

Today an agent is launched manually with a specific task, or without one. We need to determine:
- What data is required for algorithmic selection of the next task?
- Which selection criteria should apply (priority, type, dependencies, agent skills, load)?
- What is missing in the current system to support such selection?
- What are the risks and limitations?
- A sketch of a possible approach or architecture.

Outcome: a document with the analysis, conclusions, and a recommendation - whether to build it and, if so, to what scope.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Selection criteria for tasks are described (priority, type, dependencies, skills, load)
- [ ] #2 The data missing in the current system for automatic selection is described
- [ ] #3 Risks, limitations, and edge cases are identified (e.g., two tasks with equal priority)
- [ ] #4 A sketch of a possible approach or architecture is proposed
- [ ] #5 A clear conclusion is given: build it or not, and to what scope
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 Analysis document committed to docs/
<!-- DOD:END -->
