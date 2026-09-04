---
id: TASK-40
title: 'Remove tool result output: only tool invocation lines with time'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-03 20:34'
updated_date: '2026-09-04 07:25'
labels: []
dependencies: []
type: enhancement
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently the aux output (stderr) prints, besides the tool invocation line 'HH:MM:SS ⚙ name: params', the entire execution result: an indented block of stdout/stderr lines (up to 100 lines / 4000 chars), a truncation note, and completion lines ✓/✖ with duration (added in TASK-22). While the agent is working this is an unreadable stream: command contents cannot be read, there is too much information and it is useless for observation. User requirement: show only the tool invocations themselves and their execution time — 'HH:MM:SS ⚙ name: params'; do not print the result body (stdout/stderr) at all. The one-line completion lines with verdict/duration are compact — the decision to keep or remove them is made by the developer during planning; critical: the result body disappears. Also remove the result rendering code that becomes unused (truncate_result, result_note, MAX_RESULT_LINES/MAX_RESULT_CHARS, plural, etc.) and update the tests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Tool result bodies (stdout/stderr, indented line block, truncation note) are not printed in the aux output at all
- [ ] #2 Tool invocation lines are kept with the time prefix: HH:MM:SS ⚙ name: params
- [ ] #3 Unused result rendering code is removed (constants/methods truncate_result, result_note, plural, etc.)
- [ ] #4 Tests updated (test/output_streamer_test.rb, test/pi_runner_test.rb): the result body is not displayed; rake test is green (0 failures)
- [ ] #5 Affected files pass rubocop with 0 offenses
<!-- AC:END -->
