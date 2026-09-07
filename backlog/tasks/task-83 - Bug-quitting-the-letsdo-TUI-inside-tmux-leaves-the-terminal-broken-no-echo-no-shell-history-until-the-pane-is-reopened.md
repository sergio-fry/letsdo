---
id: TASK-83
title: >-
  Bug: quitting the letsdo TUI inside tmux leaves the terminal broken (no echo,
  no shell history until the pane is reopened)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-07 14:00'
updated_date: '2026-09-07 18:44'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 72000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
User report: the letsdo agent runs inside tmux. After quitting the TUI (key q, or Ctrl-C / other quit path) the terminal in that tmux pane stops working normally: typed characters do not appear (no echo), and Up/Down arrow keys no longer recall shell history. The user has to close the pane and open a fresh tmux buffer to get a working terminal again.

Likely area: the TUI session runs with stdin held in io-console raw mode for its whole lifetime (Letsdo::Tui::SessionView#with_raw_input -> @input.stdin.raw). The symptom (echo and canonical line editing gone after exit) is what a terminal left in raw mode looks like — termios (ECHO/ICANON/OPOST) is probably not restored on some quit path. Same session/terminal area and environment as TASK-82 (tmux + letsdo TUI); related TASK-42 (raw-mode input thread) and TASK-74 (quit while paused).

Reproduction context: tmux pane, run the agent TUI, quit, then use the shell in the same pane.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 After quitting the letsdo TUI inside tmux (q and Ctrl-C/SIGINT paths), the shell in the same pane is immediately usable again: typed characters echo, Up/Down recall history, and no terminal reset or new pane is needed
- [x] #2 Termios after exit matches the pre-run state (ECHO and canonical mode restored — verified via stty -a / termios dump before and after, and by normal shell interaction)
- [x] #3 A regression guard covers the quit path restoring the terminal state (unit/integration test with an injectable terminal plus a documented tmux manual check)
- [x] #4 rake test green (0 failures) and rubocop 0 offenses
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Root cause: raw mode was entered by the input thread (SessionView#input_loop -> with_raw_input -> stdin.raw), so if stop_input_thread kills the input thread the stdin.raw ensure never restores the shared tty — leaving ECHO/ICANON/OPOST off in the calling shell.
2. Move raw-mode entry to the main thread: Session#run wraps start_input_thread + work.call in with_raw_input; the main thread is never killed, so stdin.raw's ensure restores the saved termios on every quit path.
3. Remove the with_raw_input wrapper from input_loop.
4. Add regression tests with a raw-tracking injectable stdin (key-quit and raised-stop paths).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Fix: raw mode is now entered/restored by the main Session thread instead of the killable input thread, so io-console's raw block form always restores the exact saved termios. Manual tmux verification documented: run the TUI in a tmux pane, quit with q, confirm typed characters echo and Up/Down recall history.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Moved raw-mode entry from the input thread to the main thread (Session#run now wraps start_input_thread + work.call in with_raw_input), so the terminal state is restored on every quit path — a killed input thread previously left the shared tty in raw mode and broke the calling shell (no echo, no history). Removed the wrapper from input_loop. Added regression tests (key-quit and raised-stop) asserting raw mode is entered and exited exactly once. Verified: rake test 210 runs / 0 failures / 0 errors; rubocop 1.77.0 0 offenses. Manual tmux check documented in notes.
<!-- SECTION:FINAL_SUMMARY:END -->
