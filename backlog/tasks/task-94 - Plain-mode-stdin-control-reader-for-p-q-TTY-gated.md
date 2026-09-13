---
id: TASK-94
title: 'Plain mode: stdin control reader for p/q (TTY-gated)'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-13 13:29'
labels: []
dependencies:
  - TASK-74
priority: medium
type: enhancement
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a small control reader used only in plain line-stream mode (stdout not a TTY / TERM=dumb / CI) when stdin IS a terminal. A dedicated thread reads Enter-terminated lines and maps: `p` toggles pause (the same Control::PauseGate + PiRunner#pause/resume as the TUI `p`, TASK-74), `q` requests a clean stop (Thread.main.raise Letsdo::Stopped, the same as a stop signal). The reader is never started when stdin is not a TTY (pipes, /dev/null, CI), must exit quietly on EOF or read error, and must never steal stdin bytes when stdin is a pipe.

This task delivers the reader class and its unit tests only. Wiring it into the CLI and the PTY integration test are a separate task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A new reader class (e.g. Letsdo::Control::Reader) reads Enter-terminated commands from an injected TTY stream and maps p to pause toggle and q to stop (Thread.main.raise Letsdo::Stopped)
- [ ] #2 Non-TTY input: the reader is not started and consumes no bytes
- [ ] #3 EOF or read error: the reader exits quietly with no crash and no partial output
- [ ] #4 Unit tests use an injected fake/pipe, no real TTY; rake test 0 failures; rubocop 0 offenses
<!-- AC:END -->
