---
id: TASK-86
title: 'Spike: algorithmic task selection for agents — feasibility and requirements'
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-10 07:27'
updated_date: '2026-09-13 16:23'
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
- [x] #1 Selection criteria for tasks are described (priority, type, dependencies, skills, load)
- [x] #2 The data missing in the current system for automatic selection is described
- [x] #3 Risks, limitations, and edge cases are identified (e.g., two tasks with equal priority)
- [x] #4 A sketch of a possible approach or architecture is proposed
- [x] #5 A clear conclusion is given: build it or not, and to what scope
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Analysis document committed to docs/
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Audit current selection: Loop#run_batch, AgentLoop#wrapped_run/run_one_task, Providers::Backlog command + TASK_FIELDS, agent prompts |
2. Map backlog CLI capabilities (--sort priority, --ready, --type, --labels, --limit) against the selection criteria |
3. Define the criteria model: status (In Progress first), priority, ordinal tie-break, dependency readiness, assignee/skills, retry cooldown, load |
4. Identify data gaps (list JSON lacks dependencies/ready flag; no machine-readable agent skills; no cross-process coordination) |
5. Risks/edge cases: equal priority, blocked top task, transitive deps, stale deps, race on shared tasks, starvation when LLM picks a different task than the batch element |
6. Sketch options A (provider-side ordering), B (selector + task injection into prompt), C (central scheduler) and pick a scoped recommendation |
7. Write docs/task-selection.md and link it from README Guides |
8. Create the @developer task for the recommended scope; finalize TASK-86; commit
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
ANALYSIS (full text in docs/task-selection.md):
- Current selection is LLM-driven: Loop#run_batch iterates the provider batch, but AgentLoop#assign_opts default runner is `->(_task) { @agent.run }` and Agent#run takes no task, so the task object is discarded and the agent re-selects inside its prompt (agents/analyst.md, agents/developer.md "Choosing a task").
- Provider command has no --sort/--ready and TASK_FIELDS drops type/ordinal/labels/milestone, so letsdo cannot order or route.
- Criteria model: eligibility (assignee, not Done, not in retry cooldown, deps done) then order (In Progress first, priority, ordinal ascending, id ascending); type/labels/milestone as optional routing; load is not implementable per-process.
- Gaps: list JSON has no dependencies/ready flag; no machine-readable agent capabilities (front matter only model is read); no claim/lock; no selection telemetry.
- Risks: equal priority needs a deterministic tie-break (ordinal verified: 75000 before 78000); blocked top task vs "do not take others work"; stale dependencies; batch-order-vs-prompt-order starvation/retry misattribution; mid-batch new work; races on unassigned tasks.
- Recommendation: build scope A (provider-side --ready --sort priority + fields + explicit order; no contract change). Defer scope B (task injection into prompt) to a separate decision. Reject scope C (central scheduler).
- Deliverable created: TASK-95 (@developer, Medium, enhancement) for scope A; no code changed in this spike.
DOC: docs/task-selection.md, linked from README Guides.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike complete. Analysis committed to docs/task-selection.md (linked from README Guides). Findings: selection is currently LLM-driven — Loop#run_batch runs once per batch element, but the task object is discarded (AgentLoop default runner ->(_task) { @agent.run }, Agent#run takes no task) and the agent re-selects inside its prompt; the provider requests no sort/readiness and drops type/ordinal/labels/milestone. The doc covers the criteria model (eligibility, In-Progress-first, priority, ordinal/id tie-break, readiness, optional type/skill routing, load not implementable per-process), the data gaps (no dependencies/ready flag in list JSON, no machine-readable agent capabilities, no claim/lock, no selection telemetry), and risks (equal priority, blocked top task, stale deps, batch-vs-prompt starvation/retry misattribution, races). Recommendation: build scope A (provider-side --ready --sort priority + fields + explicit order), defer scope B (prompt task injection), reject scope C (central scheduler). Handoff: TASK-95 created for @developer (Medium). Verification: rake test 405 runs / 1171 assertions / 0 failures.
<!-- SECTION:FINAL_SUMMARY:END -->
