---
id: TASK-40
title: 'Remove tool result output: only tool invocation lines with time'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 20:34'
updated_date: '2026-09-04 12:48'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 29000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently the aux output (stderr) prints, besides the tool invocation line 'HH:MM:SS ⚙ name: params', the entire execution result: an indented block of stdout/stderr lines (up to 100 lines / 4000 chars), a truncation note, and completion lines ✓/✖ with duration (added in TASK-22). While the agent is working this is an unreadable stream: command contents cannot be read, there is too much information and it is useless for observation. User requirement: show only the tool invocations themselves and their execution time — 'HH:MM:SS ⚙ name: params'; do not print the result body (stdout/stderr) at all. The one-line completion lines with verdict/duration are compact — the decision to keep or remove them is made by the developer during planning; critical: the result body disappears. Also remove the result rendering code that becomes unused (truncate_result, result_note, MAX_RESULT_LINES/MAX_RESULT_CHARS, plural, etc.) and update the tests.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Tool result bodies (stdout/stderr, indented line block, truncation note) are not printed in the aux output at all
- [x] #2 Tool invocation lines are kept with the time prefix: HH:MM:SS ⚙ name: params
- [x] #3 Unused result rendering code is removed (constants/methods truncate_result, result_note, plural, etc.)
- [x] #4 Tests updated (test/output_streamer_test.rb, test/pi_runner_test.rb): the result body is not displayed; rake test is green (0 failures)
- [x] #5 Affected files pass rubocop with 0 offenses
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Decision: keep the one-line completion lines (✓/✖ name: done/error (dur)) — they are compact, carry the tool's execution time and the only failure signal now that the result body is gone; remove only the result body rendering (indented block, ✖ Error: prefix, truncation note). 2. output_streamer.rb: drop MAX_RESULT_LINES/MAX_RESULT_CHARS; tool_result(name, error:) no longer takes text and writes only the completion line; remove require of result_block.rb. 3. Delete lib/letsdo/output_streamer/result_block.rb (ResultBlock/truncate/note/plural). 4. pi_runner/events.rb: handle_tool_execution_end stops extracting result text; remove result_text/text_block/text_missing?. 5. Update test/output_streamer_test.rb and test/pi_runner_test.rb: result body (indented lines, ✖ Error:, truncation note) must NOT appear; invocation + completion lines still asserted. 6. Update docs describing the removed behavior (README.md streaming bullet, docs/usage.md stderr stream block) + CHANGELOG Changed entry. 7. Verify: rake test green (0 failures), rubocop 0 offenses, commit incl. backlog folder.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: output_streamer.rb#tool_result now takes (name, error:) only and writes the single completion line; MAX_RESULT_LINES/MAX_RESULT_CHARS constants and require removed; lib/letsdo/output_streamer/result_block.rb deleted (ResultBlock/truncate/note/plural); pi_runner/events.rb no longer extracts result text (result_text/text_block/text_missing? removed). Tests rewritten in output_streamer_test.rb + pi_runner_test.rb to assert the body (indented lines, ✖ Error:, truncation note) never appears while invocation + completion lines stay. README/docs/usage.md updated to drop result-body/truncation mentions; CHANGELOG entry added. Decision recorded: completion lines (✓/✖ with duration) kept as the execution-time + failure signal.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Tool result bodies are no longer printed to the aux output. OutputStreamer#tool_result now takes (name, error:) and writes only the one-line completion (✓/✖ name: done/error (Ns)) — kept by design as the tool's execution time and failure signal; the invocation line 'HH:MM:SS ⚙ name: params' is unchanged. Deleted the unused result rendering: lib/letsdo/output_streamer/result_block.rb (ResultBlock/truncate/note/plural), MAX_RESULT_LINES/MAX_RESULT_CHARS constants, and pi_runner result-text extraction (result_text/text_block/text_missing?). Verified: rake test 175 runs / 576 assertions / 0 failures 0 errors (incl. new refute tests proving the body, ✖ Error: and truncation note never appear); rubocop 1.77.0 over lib/bin/test — no offenses; gem build clean; manual smoke run shows only service lines on stderr. Docs updated (README streaming bullet, docs/usage.md stderr block) + CHANGELOG Changed entry.
<!-- SECTION:FINAL_SUMMARY:END -->
