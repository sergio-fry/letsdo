---
id: TASK-77
title: >-
  Bug: extra blank line inserted between every line of agent output (bloated
  log)
status: To Do
assignee: []
created_date: '2026-09-04 09:22'
labels: []
dependencies: []
references:
  - lib/letsdo/output_streamer.rb
  - lib/letsdo/pi_runner.rb
  - lib/letsdo/tui/log_buffer.rb
  - lib/letsdo/tui/renderer.rb
  - test/output_streamer_test.rb
type: bug
ordinal: 66000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When the agent runs (tool progress, results, answer text), the printed output shows an extra empty line between every line — the log becomes noticeably bloated. Symptom observed: consecutive non-empty lines of operational output are separated by a blank line. Static analysis of Letsdo::OutputStreamer (tool_start/tool_result/text_delta), Letsdo::PiRunner#result_text/handle_message_update, Letsdo::Tui::LogBuffer#append and Letsdo::Tui::Renderer shows each writer emits exactly one newline per source line and the unit tests pass, so the doubling most likely originates in how the real pi --mode json event stream shapes text blocks (e.g. multiple content text blocks each ending with a newline joined with offsets, or text_delta chunks carrying redundant line breaks). Fix outcome: the log shows each source line exactly once, no blank line between consecutive non-empty lines, in both plain (stdout/stderr) and TUI modes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A real run is captured (plain mode and TUI) and the exact stage inserting the extra blank line is identified (pi event stream shape vs streamer vs log buffer vs renderer).
- [ ] #2 Consecutive non-empty lines of agent answer text and tool result blocks are printed adjacent — exactly one newline per source line, no blank line between them — in both plain (stdout/stderr) and TUI modes.
- [ ] #3 Regression test(s) added covering line spacing of multi-line tool results and multi-chunk answer text (test/output_streamer_test.rb, and test/tui_log_buffer_test.rb if the log buffer is involved); new tests fail before the fix and pass after.
- [ ] #4 Full suite stays green: rake test ends with 0 failures, 0 errors.
<!-- AC:END -->
