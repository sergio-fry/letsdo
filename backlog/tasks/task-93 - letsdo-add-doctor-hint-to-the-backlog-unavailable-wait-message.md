---
id: TASK-93
title: 'letsdo: add doctor hint to the backlog-unavailable wait message'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-13 13:28'
updated_date: '2026-09-13 16:07'
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
- [x] #1 The first provider-nil in a run prints the message with the doctor hint (exact wording asserted in a test)
- [x] #2 Subsequent provider-nils in the same run print the short line without the hint
- [x] #3 Existing loop/cli tests updated; a new test covers the once-per-run hint; rake test 0 failures; all texts English (TASK-35)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add a per-run flag in AgentLoopTasks#provider_unavailable: the first nil of an AgentLoop#run prints "letsdo: backlog unavailable, retrying in Ns - run `letsdo doctor` to diagnose"; later nils keep today's short line.
2. Reset the flag at the start of AgentLoop#run so each session gets exactly one hint.
3. Update the existing backlog-unavailable loop test and add a new test asserting hint-once-per-run (exact wording for the first, short line for the second).
4. Add a CHANGELOG entry under Unreleased.
5. Run rake test and rubocop; record results; finalize and commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented in short iterations. (1) The message text now lives in AgentLoop#unavailable_message; provider_unavailable (AgentLoopTasks) just prints it. Rationale: AgentLoopTasks already sits at RuboCop's Metrics/ModuleLength limit (100/100), so the helper went to the AgentLoop class, which has headroom. (2) Per-run reset is done by a new small AgentLoop#prepare_run (build loop + install signal handlers + clear the hint flag); run shrank accordingly to stay within Metrics/MethodLength (10). (3) Tests: updated test_pauses_when_backlog_unavailable to include the hint; added test_doctor_hint_only_on_the_first_unavailable_message (exact first line with hint, second line short) and test_doctor_hint_returns_in_a_new_run (each run gets exactly one hint). (4) Docs: README doctor section + docs/usage.md sample line/note; CHANGELOG entry under Unreleased.

Verification: rake test -> 405 runs, 0 failures, 0 errors, 0 skips; rubocop lib bin test -> 83 files, no offenses. Targeted run: ruby -Ilib -Itest test/agent_loop_test.rb -n '/doctor_hint|unavailable/' -> 3 runs, 12 assertions, 0 failures. Manual demo with a nil provider and 3 sleeps printed: 'letsdo: backlog unavailable, retrying in 10.0s - run `letsdo doctor` to diagnose' first, then 'letsdo: backlog unavailable, retrying in 10.0s' twice.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The first 'backlog unavailable' provider-nil in a run now prints the line plus ' - run `letsdo doctor` to diagnose'; later nils in the same run keep the short line, and a new run gets the hint again. Message composition moved to AgentLoop#unavailable_message (AgentLoopTasks is at its module-length limit) with AgentLoop#prepare_run resetting the once-per-run flag. Verified: rake test 405 runs / 0 failures, rubocop 0 offenses, targeted agent_loop tests 3 runs / 12 assertions, plus a manual loop demo showing hint-then-short output. README, docs/usage.md and CHANGELOG updated.
<!-- SECTION:FINAL_SUMMARY:END -->
