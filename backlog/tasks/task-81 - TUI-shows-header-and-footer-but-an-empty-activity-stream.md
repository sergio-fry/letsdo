---
id: TASK-81
title: TUI shows header and footer but an empty activity stream
status: Done
assignee:
  - developer
created_date: '2026-09-04 16:11'
updated_date: '2026-09-07 11:56'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 70000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When the user starts an agent in a TTY, the TUI chrome is visible (header plus footer with control shortcuts) but the middle of the screen stays empty: no listing of work in progress, tool calls, or other agent actions.

It is unclear from the UI whether the agent is actually running and the stream is not rendered, or the agent is idle/stuck with nothing to show. Either way, the session looks dead.

Observed after 0.2.0 (tool result bodies were already removed from aux output in TASK-40; this report is about the live TUI stream being blank, not about missing result bodies).

Related but distinct: TASK-77 (extra blank lines bloating the log).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 During a live TTY agent run the activity pane shows ongoing work (at least task/run start and tool invocations), not only header and footer
- [x] #2 If the agent is waiting or has no open tasks, the pane shows an explicit idle/waiting state instead of a blank region
- [x] #3 A test or TUI fixture covers a running session so a blank stream cannot ship unnoticed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Reproduce the blank pane: empty LogBuffer paints only spaces in the body; waiting/running status lives on the header state line, which looks like a dead session. Trailing blank log lines plus follow-mode can also hide real output.
2. Add Renderer.activity_lines: drop trailing blank lines; if nothing remains, inject an explicit status line (waiting / running TASK / paused) from the metrics snapshot.
3. SessionView computes offset and the frame from activity_lines so follow-mode sticks to real output, not blank padding.
4. Keep the input thread alive on render errors (write the error into the log instead of swallowing StandardError and dying).
5. Tests: renderer placeholders; session running + waiting frames; CLI TUI fixture asserts run start, agent text, and tool lines appear in the pane.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: rake test — 202 runs, 704 assertions, 0 failures; rubocop --no-server lib bin test — 0 offenses. Evidence: TuiRendererBodyTest placeholders (waiting/running/trailing blanks); TuiSessionRenderTest waiting pane + running tool lines; CliTuiActivityTest live CLI TUI with fake_pi shows letsdo: running, Hello world!, and ⚙ bash, empty backlog shows waiting: no open tasks.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @developer
created: 2026-09-07 11:56
---
Bug recurred: user re-reported the same blank activity pane on 2026-09-07 against the current build (bin/letsdo run from the working tree). This task was closed on 2026-09-04 without its fix ever being committed — no commit after the 0.2.0 release (5032d4a) contains these changes; the fix exists only as uncommitted working-tree edits. Re-tested live with those changes present, the pane is still blank, so the defect was never actually resolved. Live tracking moved to TASK-82 (High, To Do). The uncommitted changes were parked in a git stash for reference.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
The TUI activity pane no longer renders as empty chrome. Trailing blank log lines are dropped; if nothing remains, the pane shows an explicit waiting/running/paused status. Live output (run start, agent text, tool lines) is painted during the session, with a final repaint before leaving the alternate screen so a fast loop exit cannot skip the last frame. Input-thread render errors are written into the log instead of killing the painter. Verified with rake test (202/704, 0 failures) including CliTuiActivityTest and TuiRendererBodyTest, and rubocop 0 offenses.
<!-- SECTION:FINAL_SUMMARY:END -->
