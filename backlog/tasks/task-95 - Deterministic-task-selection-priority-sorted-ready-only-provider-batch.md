---
id: TASK-95
title: 'Deterministic task selection: priority-sorted, ready-only provider batch'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-13 16:22'
updated_date: '2026-09-13 16:29'
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
- [x] #1 Providers::Backlog requests open, runnable tasks in priority order: the backlog command includes readiness filtering and priority sorting
- [x] #2 Blocked tasks (dependencies not done) are not offered to the loop
- [x] #3 Normalized Task keeps the fields selection needs beyond id/title/status/priority/assignees (at least ordinal; ideally also type/labels/milestone), and a growing backlog JSON schema still cannot crash the adapter
- [x] #4 The batch order is deterministic and stable for equal-priority tasks (In Progress first, then priority High>Medium>Low, then ordinal ascending, then id ascending) with a unit test for the equal-priority tie-break
- [x] #5 Letsdo::Loop stays generic: no prompt or Letsdo::Agent contract change in this task
- [x] #6 Tests cover the provider command line, readiness filtering, field normalization and the tie-break; rake test is green
- [x] #7 docs/task-selection.md and README are updated if the behavior it describes changes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Scope A from docs/task-selection.md: make the provider batch itself the authoritative runnable order.

1. Providers::Task — extend the normalized shape with ordinal, type, labels, milestone (attr_readers, safe defaults; labels coerced to Array). Keep the strict keyword constructor and field projection so unknown/growing JSON keys still cannot crash the adapter.
2. Providers::Backlog#command_line — add --ready (readiness filter) and --sort priority (priority order). The provider then re-sorts the normalized batch in Ruby for the full deterministic order the CLI does not give: In Progress first, then priority High > Medium > Low, then ordinal ascending, then id ascending (original index as the final total-order tie-break; nil/unknown priority last).
3. Extend test/fixtures/fake_backlog to simulate --ready (drop tasks with unfinished dependencies) and add ordered/blocked scenarios for the tie-break and readiness tests.
4. Tests in test/providers/backlog_test.rb: command line includes --ready/--sort priority, readiness filtering, extended field normalization, and the equal-priority deterministic tie-break.
5. Update docs/task-selection.md (how selection works today, missing-data table, recommendation status) and README (provider command line, how-it-works bullet) to match the new behavior.
6. Verify: rake test green, no Loop/Agent/prompt contract change.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Provider now requests `--ready --sort priority` and sorts the normalized batch in the adapter (In Progress first, then High>Medium>Low, then ordinal asc, then id asc; missing id/ordinal/unknown priority rank last). Extended TASK_FIELDS/Task with ordinal, type, labels, milestone. Extended the fake backlog with `--ready` simulation plus `order` and `blocked` scenarios. Tests added for argv, readiness filtering, selection-field normalization and the equal-priority tie-break; docs/task-selection.md, README and docs/usage.md updated. rake test: 410 runs, 0 failures; rubocop lib bin test: clean; gem build OK.

Validation: rake test 410 runs/1180 assertions/0 failures; rubocop --force-exclusion lib bin test (83 files) no offenses; gem build letsdo.gemspec OK; real CLI check returned TASK-95 with ordinal/type/labels populated.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Scope A of docs/task-selection.md implemented. Providers::Backlog now requests 'backlog task list --assignee <handle> --exclude-status Done --ready --sort priority --json' and re-sorts the normalized batch deterministically: In Progress first, then priority High > Medium > Low, then ordinal ascending, then id ascending (missing id/ordinal and unknown priority rank last). Providers::Task gained ordinal/type/labels/milestone while keeping strict projection, so a growing CLI schema still cannot crash the adapter. Tests cover the command line, readiness filtering (blocked task dropped), field normalization and the equal-priority tie-break (fake backlog extended with --ready simulation plus order/blocked scenarios). docs/task-selection.md, README and docs/usage.md updated. Verified: rake test 410 runs 0 failures, rubocop clean, gem build OK, real backlog CLI run returns the normalized task. No Letsdo::Loop/Agent/prompt contract change.
<!-- SECTION:FINAL_SUMMARY:END -->
