# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Letsdo::Watcher` — OS file-change watching of the backlog folder via
  inotify (Linux, through Fiddle with no external gem) with a self-pipe
  polling fallback; the orchestrator loop now wakes on a backlog change
  instead of waiting out the full `LETSDO_WAIT_SECONDS` interval. The wake
  replaces the idle-phase wait only — the startup check and the re-check
  after each finished task stay immediate provider queries.

### Fixed

- An explicitly injected control/stop sleeper is honored over the watcher
  idle path, so a CLI test that injects a sleeper completes normally even
  with the loop watcher enabled — `rake test` no longer hangs in an infinite
  idle wait.
- `Letsdo::Capture` runs its child in its own process group and terminates
  the whole group when the capture is interrupted, so a stopped capture can
  no longer leave an orphaned grandchild holding the stdout/stderr pipes.

## [0.2.0] - 2026-09-04

### Added

- `letsdo <name> --init` (and the flag-first form `letsdo --init <name>`)
  creates `agents/<name>.md` with the starter default prompt
  (`Letsdo::DefaultPrompt::TEXT`) so the prompt can be customized — the
  agent is never started. An already existing file or an unsafe name
  (contains `/` or `\`, or is `.`/`..`) is refused with a message on
  stderr and exit 1; nothing is ever written outside `agents/`
  (`Letsdo::PromptStore#create_agent`).
- Built-in default prompt (`Letsdo::DefaultPrompt::TEXT`): `letsdo <name>`
  starts the agent even without `agents/<name>.md` — the run falls back to
  the built-in process-only prompt, and letsdo announces once on stderr
  the exact path checked (`<root>/agents/<name>.md`) plus the
  `letsdo <name> --init` placement hint. `UnknownAgentError` is removed:
  with the fallback there are no unknown agents, the base `Letsdo::Error`
  remains the package error surface.
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
- Gemspec metadata: `homepage`, `homepage_uri`, `source_code_uri`,
  `changelog_uri`, `allowed_push_host`.
- `CHANGELOG.md`.
- Default RuboCop 1.77 as a development dependency; CI fails the build
  on style violations.

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
  even then.
- CLI tests no longer collide on a shared `/tmp` “tasks already served”
  marker after Minitest reseeds `Kernel.srand` per test class.

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

[Unreleased]: https://github.com/sergio-fry/letsdo/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/sergio-fry/letsdo/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sergio-fry/letsdo/releases/tag/v0.1.0
