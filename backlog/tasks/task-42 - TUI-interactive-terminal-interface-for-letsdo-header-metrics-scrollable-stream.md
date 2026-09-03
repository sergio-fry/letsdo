---
id: TASK-42
title: >-
  TUI: interactive terminal interface for letsdo (header metrics + scrollable
  stream)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-03 21:09'
labels: []
dependencies:
  - TASK-39
priority: high
type: enhancement
ordinal: 31000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the interactive TUI designed in TASK-38 (full UX spec recorded in TASK-38 comments; read them first). letsdo <name> in a TTY shows a full-screen interface: header zone with agent name + identifier (assignee handle), tasks done in this session, session timer, tasks remaining, elapsed time of the current task (and a waiting-mode indicator when no tasks are open); central zone — the live scrollable stream of agent text and tool lines (exactly what Letsdo::OutputStreamer emits); footer with key help. Selected stack (decision in TASK-38): pure-Ruby, in-process, on tty-screen/tty-cursor/tty-reader — NO curses/ncurses, NO external ratatui/bubbletea binary, NO PTY. Architecture: renderer is a pure function (metrics snapshot, log buffer, width/height) -> framed String; a metrics facade fed by the loop driver (Letsdo::Loop stays generic/injectable — wire callbacks at CLI/AgentLoop level); OutputStreamer gets an injectable log target in TUI mode; PiRunner event loop unchanged. Mode selection: TUI only when stdout is a TTY (and TERM != dumb); otherwise the current plain line-stream output byte-identical to today. Fallback guarantees CI (TASK-36) and all existing tests keep passing unchanged. Add tty-screen, tty-cursor, tty-reader as runtime dependencies to letsdo.gemspec. All UI texts in English (TASK-35); code passes rubocop (TASK-37). Note: TASK-40 changes what the streamer prints (tool result bodies removed) — the TUI consumes whatever the streamer emits, no coupling.,
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 letsdo <name> with stdout on a TTY starts the full-screen TUI: header (name + handle, done-in-session counter, ticking session timer, tasks remaining from the backlog provider, current-task elapsed, waiting-mode indicator), central scrollable combined log of agent text + tool lines, footer with key help; alternate screen entered/restored cleanly
- [ ] #2 TUI is engaged ONLY when stdout is a TTY and TERM != dumb; non-TTY output (pipes/CI/tests) equals current plain line-stream behavior — no TUI escape codes, existing tests unchanged and green
- [ ] #3 Keyboard: up/down one-line scroll, PgUp/PgDn page, Home/End top/bottom, auto-follow while at bottom (tail -f semantics), p pause/resume (display freeze, PAUSED indicator, log keeps buffering), r refresh (immediate backlog re-query for 'left'), q quit identical to signal stop (pi child terminated, terminal restored, exit 0); SIGWINCH resize repaints without corruption
- [ ] #4 Metrics sources per TASK-38 spec: done counter = completed runs from the loop driver; session timer = monotonic clock from TUI start; remaining = latest provider task count; current-task elapsed = monotonic from run start; waiting mode shown when no run active
- [ ] #5 Renderer is a pure function over (metrics, log buffer, size) and input is injectable — tests render, scroll, pause and quit wiring with injected IO/StringIO, no real TTY in any test; rake test green (0 failures)
- [ ] #6 UI texts in English (TASK-35); rubocop 0 offenses (TASK-37); README documents the TUI mode and keys; new runtime deps (tty-screen, tty-cursor, tty-reader) listed in letsdo.gemspec
- [ ] #7 Affected letsdo components covered: new lib/letsdo/tui/* (renderer, terminal, input, metrics facade), lib/letsdo/cli.rb (mode selection + wiring), loop driver/AgentLoop (metrics callbacks), lib/letsdo/output_streamer.rb (injectable log target), letsdo.gemspec, tests, README
<!-- AC:END -->
