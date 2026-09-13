---
id: TASK-90
title: >-
  TUI: name the tmux window after the agent (developer/tester/analyst) instead
  of "ruby"
status: Done
assignee:
  - '@developer'
created_date: '2026-09-13 11:34'
updated_date: '2026-09-13 16:02'
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
- [x] #1 Running `letsdo developer` inside tmux shows a window label containing the agent name ("developer"), not "ruby", for the whole session
- [x] #2 The label survives tmux automatic-rename (tmux must not overwrite it with the foreground process name while the session runs)
- [x] #3 On exit (normal stop, SIGINT/SIGTERM/Stopped, or a crash) the previous window label is restored, and any temporary tmux state is cleaned up
- [x] #4 Outside tmux (or when the output stream is not a TTY) nothing extra is written: no title escape sequences, no reliance on the tmux binary
- [x] #5 The TUI frame, log buffer, and plain mode output are unaffected by the title handling
- [x] #6 Tests cover setting and restoring the title through an injected output stream, and the tmux-detection path with the tmux command stubbed
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 rake test is green (full suite, no failures or errors)
- [x] #2 rubocop --no-server lib bin test reports no offenses
- [x] #3 docs/usage.md and CHANGELOG.md document the tmux window naming
<!-- DOD:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add Letsdo::Tui::WindowTitle (lib/letsdo/tui/window_title.rb): a self-gating component that names the tmux window after the agent and restores the previous label. Detection = TMUX env set AND stream is a TTY; outside tmux it is a no-op (no escape sequences, no tmux calls). All tmux access goes through an injectable runner (tests stub it); failures are swallowed so title handling can never break a session.
2. Mechanism (verified against tmux 3.4): an OSC-2 title escape only sets the pane title, tmux automatic-rename still labels the window after the foreground process (ruby), so the component captures the previous window name + automatic-rename value, disables automatic-rename, renames the window, and writes the OSC-2 title to the injected stream. Restore renames back, unsets/restores automatic-rename so no temporary tmux state is left, and resets the title escape.
3. Require the new file from lib/letsdo/tui.rb and list the component in the TUI docs there.
4. Wire it into Tui::Session as an optional injected 'title:' component: install after terminal.enter, restore in the existing ensure (so normal stop, Stopped/raise and crash all restore). Build it in CLI::BuilderTui#tui_session_args with stream: @stdout, env: @env.
5. Tests: new test/tui_window_title_test.rb for detection, install/restore through an injected (fake TTY) stream, tmux commands via a stubbed runner, no-op outside tmux, and runner-failure resilience; session-level test that install/restore run on quit and on a raised work block.
6. Update docs/usage.md (tmux window naming in the several-agents section) and CHANGELOG Unreleased.
7. Verify: rake test (all green), rubocop lib bin test (no offenses).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented Letsdo::Tui::WindowTitle (lib/letsdo/tui/window_title.rb), gated on TMUX env + TTY stream, all tmux calls through an injectable runner and swallowed on failure. Session wires it as an optional title: component (install after terminal.enter, restore in the existing ensure), built in CLI::BuilderTui#tui_session_args from the injected stdout/env. The terminal lifecycle moved into SessionTerminal (lib/letsdo/tui/session/terminal.rb) to keep Session within the class-length limit.

Verification: rake test -> 403 runs, 1166 assertions, 0 failures, 0 errors, 0 skips (exit 0). rubocop --no-server lib bin test -> 83 files, no offenses. Focused files: tui_window_title_test 15 runs/32 assertions, tui_session_test 23 runs, cli_builder_test 16 runs, tui_terminal_test 8 runs, all green.

Manual tmux 3.4 end-to-end (auto-named window running a script that calls install('developer') then restore): mid-session list-windows shows window_name=developer automatic_rename=0 (label survives >1s of automatic-rename); after restore window_name=ruby and automatic-rename is unset again, i.e. no temporary tmux state left. A second run with an explicitly named window confirmed the captured explicit value is restored.

Docs: docs/usage.md (TUI section + several-agents section) and CHANGELOG Unreleased.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Inside tmux a TUI session now labels its window with the agent name and restores the previous label (and automatic-rename setting) on every exit path; outside tmux nothing is written and the tmux binary is never invoked. Implemented as Letsdo::Tui::WindowTitle with an injectable tmux runner, wired into Tui::Session via SessionTerminal and CLI::BuilderTui#tui_session_args. Verified with the full rake test suite (403 runs, 0 failures), rubocop lib bin test (no offenses), and a real tmux 3.4 run (developer label held through automatic-rename, previous label and unset automatic-rename restored on exit).
<!-- SECTION:FINAL_SUMMARY:END -->
