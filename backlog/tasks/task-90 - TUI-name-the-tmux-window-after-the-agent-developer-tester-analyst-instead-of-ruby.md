---
id: TASK-90
title: >-
  TUI: name the tmux window after the agent (developer/tester/analyst) instead
  of "ruby"
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-13 11:34'
updated_date: '2026-09-13 13:29'
labels: []
dependencies: []
references:
  - lib/letsdo/tui/terminal.rb
  - lib/letsdo/cli/builder.rb
priority: medium
type: enhancement
ordinal: 79000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When letsdo is run inside tmux, the tmux window/tab is always labeled "ruby" (tmux auto-rename falls back to the foreground process name, which is the Ruby interpreter, not the agent). With several agents running side by side (one pane per agent) the labels are indistinguishable, so the operator cannot tell which pane runs developer, tester, or analyst. Desired outcome: while a letsdo TUI session is running, the tmux window is labeled with the agent name passed on the CLI (`letsdo <name>`), and the previous name is restored on exit.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Running `letsdo developer` inside tmux shows a window label containing the agent name ("developer"), not "ruby", for the whole session
- [ ] #2 The label survives tmux automatic-rename (tmux must not overwrite it with the foreground process name while the session runs)
- [ ] #3 On exit (normal stop, SIGINT/SIGTERM/Stopped, or a crash) the previous window label is restored, and any temporary tmux state is cleaned up
- [ ] #4 Outside tmux (or when the output stream is not a TTY) nothing extra is written: no title escape sequences, no reliance on the tmux binary
- [ ] #5 The TUI frame, log buffer, and plain mode output are unaffected by the title handling
- [ ] #6 Tests cover setting and restoring the title through an injected output stream, and the tmux-detection path with the tmux command stubbed
<!-- AC:END -->
