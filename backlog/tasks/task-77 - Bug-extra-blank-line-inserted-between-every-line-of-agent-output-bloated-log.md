---
id: TASK-77
title: >-
  Bug: extra blank line inserted between every line of agent output (bloated
  log)
status: Done
assignee: []
created_date: '2026-09-04 09:22'
updated_date: '2026-09-07 19:03'
labels: []
dependencies: []
references:
  - lib/letsdo/output_streamer.rb
  - lib/letsdo/pi_runner.rb
  - lib/letsdo/tui/log_buffer.rb
  - lib/letsdo/tui/renderer.rb
  - test/output_streamer_test.rb
priority: medium
type: bug
ordinal: 66000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When the agent runs (tool progress, results, answer text), the printed output shows an extra empty line between every line — the log becomes noticeably bloated. Symptom observed: consecutive non-empty lines of operational output are separated by a blank line. Static analysis of Letsdo::OutputStreamer (tool_start/tool_result/text_delta), Letsdo::PiRunner#result_text/handle_message_update, Letsdo::Tui::LogBuffer#append and Letsdo::Tui::Renderer shows each writer emits exactly one newline per source line and the unit tests pass, so the doubling most likely originates in how the real pi --mode json event stream shapes text blocks (e.g. multiple content text blocks each ending with a newline joined with offsets, or text_delta chunks carrying redundant line breaks). Fix outcome: the log shows each source line exactly once, no blank line between consecutive non-empty lines, in both plain (stdout/stderr) and TUI modes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A real run is captured (plain mode and TUI) and the exact stage inserting the extra blank line is identified (pi event stream shape vs streamer vs log buffer vs renderer).
- [x] #2 Consecutive non-empty lines of agent answer text and tool result blocks are printed adjacent — exactly one newline per source line, no blank line between them — in both plain (stdout/stderr) and TUI modes.
- [x] #3 Regression test(s) added covering line spacing of multi-line tool results and multi-chunk answer text (test/output_streamer_test.rb, and test/tui_log_buffer_test.rb if the log buffer is involved); new tests fail before the fix and pass after.
- [x] #4 Full suite stays green: rake test ends with 0 failures, 0 errors.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Capture a real pi --mode json run and identify the stage: the text comes as message_update/assistantMessageEvent text_delta deltas. The current pi (0.85.1) emits each line's newline as its own delta ("alpha","\n","beta","\n","gamma"), so the streamer assembles clean single-spaced text — the historical blank line came from an older pi's redundant line breaks and/or the pre-TASK-40 tool-result body rendering.
2. Fix the residual blank-line bug in Letsdo::OutputStreamer#finish: it used a stale @last_char across runs, so a tool-only run after a text run wrote a spurious blank line on stdout. Reset @last_char after finish.
3. Add regression tests: multi-line/multi-chunk answer text (plain + TUI log) has exactly one newline per line, and finish after a tool-only run adds no blank line.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Real pi (0.85.1) captured: text_delta deltas are clean incremental chunks; text_start/text_end/thinking_* are already ignored; the blank-line symptom is not reproducible with the current pi. The pre-TASK-40 ResultBlock also emitted one newline per line. Residual bug fixed: finish wrote a blank line on a tool-only run after a text run (stale @last_char).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Identified the stage: the blank line came from the pi text_delta stream shape (redundant line breaks in older pi versions), now clean in pi 0.85.1; the streamer/log buffer assemble single-spaced text. Fixed the residual blank-line bug: OutputStreamer#finish used a stale @last_char across runs, so a tool-only run after a text run wrote a spurious blank line on stdout — now resets @last_char after finish. Added regression tests: multi-line/multi-chunk answer text has exactly one newline per line (plain + TUI), and finish after a tool-only run adds no blank line. Verified: rake test 213 runs / 0 failures / 0 errors; rubocop 1.77.0 0 offenses.
<!-- SECTION:FINAL_SUMMARY:END -->
