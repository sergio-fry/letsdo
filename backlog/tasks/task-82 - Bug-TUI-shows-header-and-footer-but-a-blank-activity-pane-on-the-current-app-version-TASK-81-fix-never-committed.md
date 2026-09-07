---
id: TASK-82
title: >-
  Bug: TUI shows header and footer but a blank activity pane on the current app
  version (TASK-81 fix never committed)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-07 11:52'
updated_date: '2026-09-07 13:43'
labels: []
dependencies: []
priority: high
type: bug
ordinal: 71000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
User report: running the current version of the app in a TTY renders only the header and footer; the pane where the agent's ongoing work should appear stays empty and nothing is printed, so the session looks dead.

Investigation: the symptom matches TASK-81 (TUI shows header and footer but an empty activity stream), which is marked Done on 2026-09-04 — but its fix was never committed. The changes exist only as uncommitted working-tree edits: lib/letsdo/tui/renderer.rb, lib/letsdo/tui/renderer/activity.rb, lib/letsdo/tui/session/view.rb plus TUI tests (tui_renderer_test.rb, tui_session_test.rb, cli_test.rb). The latest commit is the 0.2.0 release (5032d4a, 2026-09-04 16:10); TASK-81 was closed at 16:23, i.e. after the release, and no commit contains the fix. The working tree currently passes rake test (202 runs, 706 assertions, 0 failures), so the fix looks functional but never shipped.

Consequence: any installed gem or clean committed checkout — the "current version" the reporter runs — still renders the empty activity pane.

Related: TASK-81 (previous fix, unshipped). Distinct from TASK-77 (extra blank lines bloating the log).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 In a real tmux session (the reporter's environment) the TUI shows the title header on the first row, the footer on the bottom row, and live agent content (run start, text, tool lines) in the activity pane — not a blank region
- [x] #2 The pane no longer scrambles per repaint: across a live run the title stays on row 0 and content does not flash-then-clear (verified with tmux capture-pane snapshots)
- [x] #3 A regression guard is committed: Letsdo::Tui::Terminal#render emits CRLF row separators and tui_terminal_test asserts it (io-console raw mode clears OPOST on the shared tty, so frames with bare LF break)
- [x] #4 rake test passes with 0 failures and rubocop reports 0 offenses on the changed files
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Root cause (corrected): the TUI input thread holds stdin in io-console raw mode for the whole session; raw mode clears OPOST on the shared tty, so bare \n output is no longer translated to \r\n. Every frame row after the first therefore starts at the previous row's end column and wraps/scrolls, scrambling the pane — the reported "content flashes then clears, blank most of the time" (reproduced in tmux; user environment). The earlier "reserve the last row" theory was an artifact of shell-prompt newlines in static cat replays and was reverted.
2. Fix: Letsdo::Tui::Terminal#render writes row separators as CRLF (frame.gsub("\n", "\r\n")) — correct in raw mode (OPOST off) and harmless where ONLCR already expands LF. No renderer/API change.
3. Regression guard: tui_terminal_test asserts render("head\nbody\ntail") -> HOME + "head\r\nbody\r\ntail" and no trailing newline.
4. Verified: rake test 197 runs / 680 assertions, 0 failures; rubocop 0 offenses on changed files. Live tmux check (fake_pi, clean 0.2.0): before fix title on row 0 in 0/54 snapshots and footer scrambled to the top row; after fix title on row 0 in every running snapshot (49/49), one footer at the bottom row (R23), live content stable, only 2 blank<->content transitions (start and quit).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Reproduction attempt (2026-09-07). Harness: REAL bin/letsdo under a REAL PTY (24x100, stdin/stdout true TTYs, TERM=xterm-256color), real Letsdo::Loop + agent fixtures: fake_pi (deterministic JSON stream: text + bash tool lines) and real pi v0.85 (controlled prompt: text-only answer, no tools). Backlog fixture: 2 open tasks then empty.

RESULT: blank pane NOT reproduced in any combination. In all live runs the activity pane filled with content live: "letsdo: <name> has N open task(s)", run start "letsdo: running <name> for TASK-x", agent text ("Hello, world!" / "READY"), tool lines ("HH:MM:SS ⚙ bash...", "✓ bash: done"), then "letsdo: no open tasks..., retrying". Header state line ticks (done/left/task/elapsed). Tested: clean committed 0.2.0 tree x {fake_pi, real pi}, and the parked TASK-81 dirty tree (reconstructed clone: stash@{0} patch + lib/letsdo/tui/renderer/{activity,text}.rb, 202 tests green) x real pi.

Closest match to the report: during LONG silent agent work (model thinking, no output) the 20-row body shows only 2-3 sparse service lines at the top and blank padding below; the only live "working" indicator is the state line ("task TASK-1 · mm:ss"). In a taller terminal with a silent multi-minute run this reads as "header + footer, empty middle".

Not reproduced: a frozen/fully-blank pane, or a session where content never appears.

REPRODUCED (2026-09-07, inside tmux 3.4). Environment: clean committed 0.2.0 base + fake_pi backend, letsdo launched in a real tmux pane (100x24), pane captured via capture-pane every ~0.2-0.4s.

Evidence (live run): 54 pane snapshots over ~21s — in 52 the TOP row of the pane shows the FOOTER line ("↑/↓ PgUp/PgDn scroll ... q quit"); the title header never sits at row 0 (0/54); the divider row is never found anywhere; agent content appears only as stray fragments (e.g. "13:17:46 ✓ bash: done (0.0s)" immediately under the footer line); the rest of the pane is blank. I.e. the screen is scrambled by a vertical scroll that happens on (nearly) every repaint: content flashes in, then the frame is pushed up and the pane looks empty. Matches the reporter: "данные проскакивают и экран очищается, большую часть времени пусто, заголовок и футер видны".

Isolated root cause (single-frame experiments in a tmux pane): painting a frame that occupies EXACTLY the full terminal height (24 rows; footer written on the very bottom line) makes tmux scroll the alternate screen up one line — the top row (title header) is pushed off and content shifts. Painting only height-1 rows (bottom line untouched) renders correctly and stably. Reproduces with padded and unpadded rows; width is irrelevant; only final-row occupancy matters.

Why: letsdo renderer computes body_height = terminal_height - HEADER - FOOTER - DIVIDER and always paints terminal_height rows total, with the footer on the last screen line. In tmux that last-line write + CRLF handling scrolls once per frame; repeated repaints (1s tick + every log change) scramble the pane. A raw-PTY run looked fine because naive byte parsing does not model terminal scroll semantics; the defect is tmux/terminal-scroll specific (the reporter uses tmux). Backend-independent: reproduced with fake_pi. The parked TASK-81 changes do not touch this layer (body placeholder rendering), which is why the blank persisted for the reporter with those changes present.

Fix direction (NOT applied yet, pending plan): never write on the bottom terminal line — paint at most terminal_height - 1 rows (or reserve one line), then verify with capture-pane inside tmux that the title stays at row 0 and content stops flickering.

ROOT CAUSE CORRECTED (2026-09-07): the blank pane is NOT about frame height. letsdo keeps stdin in io-console raw mode for the whole TUI session (SessionView#with_raw_input -> @input.stdin.raw). IO#raw clears OPOST on the shared tty, so bare \n on output is never expanded to \r\n; the cursor never returns to column 0 and every frame row after the first wraps/scrolls. Isolated proof in tmux: repeated 23-row frames with raw HELD + "\n" separators produce the exact live bug (title lost, two footer rows, scrambled); with raw HELD + "\r\n" the same frames are clean. Raw held for only an instant (mimic4) or not at all renders fine, which is why initial experiments misled. The earlier "reserve the last terminal row" direction was based on static `cat` replays where the trailing shell prompt newline (not the frame) caused the scroll; that change was reverted.
Fix implemented: Letsdo::Tui::Terminal#render now emits CRLF row separators (frame.gsub("\n", "\r\n")); renderer unchanged.
Verification in tmux (clean 0.2.0 + fake_pi): 59 pane snapshots — title on row 0 in all 49 running snapshots (was 0/54), single footer at bottom row 23 (was 52/54 footer at the top), agent content visible and stable (48 snapshots), only 2 blank/content transitions (session start and quit). rake test 197/680 green; rubocop 0 offenses.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @developer
created: 2026-09-07 11:56
---
2026-09-07 user verification: ran bin/letsdo from the working tree (which then already contained TASK-81's uncommitted renderer changes: activity_lines/status placeholders, session/view.rb, TUI tests) and the blank activity pane reproduces. So TASK-81's patch does not cure the live bug and the root cause is deeper (AC #4 branch). Investigation base reset to the clean committed 0.2.0 tree: TASK-81's uncommitted changes were parked in a git stash (message 'TASK-81 uncommitted fix (parked, see TASK-82)'), untracked lib/letsdo/tui/renderer/ sources moved to /tmp/task81_parked/. TASK-45 (wake-on-file-change loop) moved back to To Do and now depends on this task — deferred until this bug is resolved.
---

author: @developer
created: 2026-09-07 12:11
---
Reproduction attempt done (4 live PTY runs: clean 0.2.0 and parked TASK-81 tree, x fake_pi and real pi). The pane is NOT blank in this environment — activity lines render live in every run. Closest to the report: near-empty body during long silent agent thinking, with the run indicator only on the state line. To pin the real difference need reporter details: (1) what did the 2nd line (state) show while 'working' — task label+elapsed, or 'waiting…'? (2) did ANY text ever appear in the middle? (3) terminal emulator / tmux / TERM / window height; (4) exact command + cwd.
---

author: @developer
created: 2026-09-07 13:23
---
REPRODUCED. Root cause isolated: letsdo paints frames that fill exactly the terminal height (footer on the last line); inside tmux that scrolls the alt screen one line per repaint, scrambling the pane (footer migrates to the top row, title is pushed off, content only flashes). Single-frame tmux experiments confirm: full-height frame = top line lost; height-1 frame = stable. Rendering is backend-independent (fake_pi reproduces on clean 0.2.0). Fix direction recorded in notes; not applied.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Fixed the blank activity pane (TASK-82). Root cause: the TUI input thread holds stdin in io-console raw mode for the whole session; raw mode clears OPOST on the shared tty, so frame rows joined with bare \n were never carriage-returned to column 0 and every row after the first wrapped/scrolled — the pane scrambled on each repaint (title pushed off, content flashing then clearing). Reproduced live in tmux (user environment) on clean 0.2.0 with fake_pi: before the fix the title sat on row 0 in 0/54 capture-pane snapshots and the footer was scrambled to the top row; the same bytes rendered fine without raw mode, and isolated mimics (raw held + \n vs \r\n) proved the OPOST mechanism.
Fix: Letsdo::Tui::Terminal#render now writes CRLF row separators (frame.gsub("\n", "\r\n")) — correct under raw mode and harmless elsewhere; no renderer or API change. Regression guard: TuiTerminalTest#test_render_uses_crlf_row_separators.
Verified: rake test 197 runs / 680 assertions / 0 failures; rubocop 0 offenses on changed files. Live tmux run after the fix: title on row 0 in 49/49 running snapshots, single footer on the bottom row (R23), agent content visible and stable, only 2 blank<->content transitions (start and quit). TASK-81 relationship recorded; its parked uncommitted changes remain stashed (not part of this fix).
<!-- SECTION:FINAL_SUMMARY:END -->
