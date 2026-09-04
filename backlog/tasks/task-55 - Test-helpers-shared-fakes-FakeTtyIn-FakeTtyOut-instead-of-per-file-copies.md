---
id: TASK-55
title: 'Test helpers: shared fakes (FakeTtyIn/FakeTtyOut) instead of per-file copies'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:31'
labels: []
dependencies:
  - TASK-42
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Part of the TASK-50 refactoring proposal (Phase 1), test-harness dedup only. FakeTtyOut/FakeTtyIn (terminal/keyboard fakes reporting tty? true) are currently defined inside cli_test.rb, and the TUI test files each hand-roll similar StringIO / injected-size / scripted-key patterns. Move these fakes into a shared test/helpers/ location required from test_helper.rb or the using files, so every suite reuses one definition. Purely mechanical: zero behavioral change, same assertions and coverage, no production code touched.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 FakeTtyOut/FakeTtyIn (as currently defined in test/cli_test.rb) and the common TUI test patterns (injected size provider, scripted key bytes) live in test/helpers/ and are required by the using test files
- [ ] #2 No duplicated fake definitions remain: grep for the fake class definitions under test/ matches exactly one location
- [ ] #3 All existing tests pass with unchanged behavior and coverage; rake test green (0 failures)
- [ ] #4 rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); no production code changed
- [ ] #5 Affected letsdo components covered: test/helpers/ (new), test/test_helper.rb, test/cli_test.rb, test/tui_*_test.rb
<!-- AC:END -->
