# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Real pause semantics for the TUI 'p' key: mid-run the pi group is
  suspended at the kernel level (SIGSTOP via `Letsdo::PiRunner#pause`,
  resume via SIGCONT); between runs a shared `Letsdo::Control::PauseGate`
  holds new runs until resume. The footer flips between `p pause` and
  `p resume`.
- `SIGHUP` (terminal closed) stops the loop the same way as `SIGINT`/
  `SIGTERM`.
- Prompt stop of a paused pi: `PiRunner#terminate` now reaps the child
  during its grace wait (WNOHANG) instead of polling the process table,
  so a signal-killed child's zombie state can no longer stall the stop
  for the full grace period.

### Changed

- Tool result bodies (indented stdout/stderr blocks, truncation notes,
  `✖ Error:` markers) are no longer printed to the aux output; the stream
  shows only tool invocations (`HH:MM:SS ⚙ name: args`) and a one-line
  completion with duration (`✓/✖ name: done/error (Ns)`).
- `Session#quit` sets the stop flag before raising `Letsdo::Stopped`, so
  the input thread renders no frames during teardown.

### Fixed

- `rake test` no longer prints `Open3.capture3` reader-thread dumps
  (`IOError: stream closed in another thread`): `Letsdo::BacklogTasks` now
  captures the backlog CLI output through `Letsdo::Capture`, whose reader
  threads tolerate the pipes being closed when a stop (TUI quit, signal)
  interrupts an in-flight backlog call and whose cleanup reaps the child
  even then. Verified green runs show only Minitest dots and the summary;
  real failures and errors still print.

### Added

- Gemspec metadata: `homepage`, `homepage_uri`, `source_code_uri`, `changelog_uri`,
  `allowed_push_host`.
- `CHANGELOG.md`.

## [0.1.0] - 2026-09-04

### Added

- Initial release of letsdo — a local agent worker for Backlog.md/markdown tasks.
- OOP structure: `Letsdo::PromptStore` (agents/), `Letsdo::OutputStreamer` and
  `Letsdo::PiRunner` (pi --mode json), `Letsdo::Agent` (one run), `Letsdo::Loop`
  (orchestrator loop), `Letsdo::CLI`.
- Interactive TUI (header metrics, scrollable stream) in TTY mode; plain
  line-stream mode for pipes/CI/tests.
- Minitest tests; CI (GitHub Actions) builds the gem and runs tests on every push.
- Local executable `letsdo`.

[Unreleased]: https://github.com/sergio-fry/letsdo/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/sergio-fry/letsdo/releases/tag/v0.1.0