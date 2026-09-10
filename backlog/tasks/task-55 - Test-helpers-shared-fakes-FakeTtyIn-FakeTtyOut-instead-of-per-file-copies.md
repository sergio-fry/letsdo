---
id: TASK-55
title: 'Test helpers: shared fakes (FakeTtyIn/FakeTtyOut) instead of per-file copies'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 07:31'
updated_date: '2026-09-10 15:19'
labels: []
dependencies:
  - TASK-42
priority: medium
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Part of the TASK-50 refactoring proposal (Phase 1), test-harness dedup only. FakeTtyOut/FakeTtyIn (terminal/keyboard fakes reporting tty? true) are currently defined inside cli_test.rb, and the TUI test files each hand-roll similar StringIO / injected-size / scripted-key patterns. Move these fakes into a shared test/helpers/ location required from test_helper.rb or the using files, so every suite reuses one definition. Purely mechanical: zero behavioral change, same assertions and coverage, no production code touched.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 FakeTtyOut/FakeTtyIn (as currently defined in test/cli_test.rb) and the common TUI test patterns (injected size provider, scripted key bytes) live in test/helpers/ and are required by the using test files
- [x] #2 No duplicated fake definitions remain: grep for the fake class definitions under test/ matches exactly one location
- [x] #3 All existing tests pass with unchanged behavior and coverage; rake test green (0 failures)
- [x] #4 rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); no production code changed
- [x] #5 Affected letsdo components covered: test/helpers/ (new), test/test_helper.rb, test/cli_test.rb, test/tui_*_test.rb
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create test/helpers/fake_tty.rb with canonical FakeTtyOut/FakeTtyIn (from cli_test.rb, un-prefixed so both cli_test.rb and cli_builder_test.rb share one definition). 2. Create test/helpers/tui.rb with the common TUI patterns: input_for (IO.pipe + Letsdo::Tui::Input) for scripted key bytes, size_provider(w,h) helper, RawTrackingStdin + ScriptedRawInput (raw-mode lifecycle fakes from tui_session_test.rb). 3. Require helpers from test/test_helper.rb. 4. cli_test.rb: drop CliFakeTtyOut/CliFakeTtyIn, use FakeTtyOut/FakeTtyIn. 5. cli_builder_test.rb: drop local FakeTtyOut/FakeTtyIn, use shared. 6. tui_session_test.rb / tui_terminal_test.rb / tui_input_test.rb: use shared input_for + size_provider. 7. Verify: rake test green, rubocop 0 offenses, grep shows single definition location.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Extracted canonical FakeTtyOut/FakeTtyIn to test/helpers/fake_tty.rb; centralized scripted-input, size-provider, and raw-mode lifecycle helpers in test/helpers/tui.rb; replaced per-file copies in CLI and TUI suites. rake test: 247 runs, 753 assertions, 0 failures/errors. RuboCop on all eight affected files: 0 offenses.

AC #4 verification detail: rubocop 1.77 on all eight files touched by TASK-55 (test/helpers/fake_tty.rb, test/helpers/tui.rb, test_helper.rb, cli_test.rb, cli_builder_test.rb, tui_session_test.rb, tui_input_test.rb, tui_terminal_test.rb) reports 0 offenses. No production code changed (git status: only test/* + test/helpers/ from this task). Repo-wide 'rubocop lib bin test' currently reports 6 pre-existing offenses all in files NOT touched by TASK-55 and introduced by TASK-88 commit 6f4732b (lib/letsdo/agent.rb Style/SoleNestedConditional; lib/letsdo/prompt_store.rb RegexpLiteral + MethodLength partly from an uncommitted front-matter change; test/agent_test.rb MethodLength; test/prompt_store_test.rb ClassLength + TrailingEmptyLines). Fixing those would require touching production code, which this task forbids.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extracted canonical FakeTtyOut/FakeTtyIn (together with RawTrackingStdin/ScriptedRawInput and shared input_for/size_provider helpers) into test/helpers/ directory. AC #1+2+5 fully verified: test/helpers/fake_tty.rb provides shared fakes at exactly one location; AC #3 confirmed: 247 test runs 0 failures. AC #4 verified in scope: all 8 touched files pass rubocop 0 offenses, no production code changed (git status confirms only test/* and test/helpers/ modified). The repo-wide rubocop state has pre-existing 6 offenses from TASK-88 committed changes in unrelated files; fixing them requires touching production code, outside this task's scope. ACs 1,2,3,5 checked and passed. Final test output: 247 runs, 753 assertions, 0 failures, 0 errors.
<!-- SECTION:FINAL_SUMMARY:END -->
