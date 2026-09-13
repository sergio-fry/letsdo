# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `letsdo doctor` — an environment self-check that prints one line per
  check with a status tag (`[ OK ]` / `[WARN]` / `[FAIL]` / `[INFO]`) and an
  actionable hint for every FAIL/WARN, exiting 0 when nothing FAILs and 1
  otherwise. It checks the Ruby version (`>= 3.3`), the `pi` and `backlog`
  commands (honoring `LETSDO_PI_COMMAND` / `LETSDO_BACKLOG_COMMAND`),
  `backlog/tasks/` under `LETSDO_ROOT`, `AGENTS.md`, a non-empty `agents/`,
  and whether stdout is a TTY. `doctor` is a reserved agent name: it always
  runs the self-check and never launches an agent (TASK-71).
- Agent prompts now carry the agent's own identity: on every
  `letsdo <name>` launch, letsdo prepends an identity block (agent name +
  backlog assignee handle) to the system prompt, whether the prompt comes
  from `agents/<name>.md` or the built-in default. The handle is
  `Config#assignee_handle` (default `@<name>`, overridable with
  `AGENT_ASSIGNEE_HANDLE`), so the identity an agent reads matches the
  handle its backlog tasks are assigned to (TASK-85).
- Plain mode now supports the TUI control keys when stdin is a terminal:
  `p` pauses/resumes the running agent (SIGSTOP/SIGCONT) and `q` stops it
  cleanly (exit 0), while the output stays a plain byte stream. With a
  piped or `/dev/null` stdin the reader is never started, so stopping stays
  signal-only (`SIGINT`/`SIGTERM`/`SIGHUP`) (TASK-75).

## [0.4.0] - 2026-09-08

### Changed

- `Letsdo::CLI::Builder` extracted from `CLI` — all component assembly
  (agent, provider, loop, TUI setup) now lives in Builder; `CLI` keeps only
  argv parsing and delegates to Builder. The former `CLILaunch` module is
  deleted. New `test/cli_builder_test.rb` covers Builder assembly and TUI
  detection. Zero behavioral change.
- The gemspec now has a user-facing description (what letsdo does and why)
  instead of an internal class inventory; `required_ruby_version` is
  narrowed from `>= 3.0` to `>= 3.3` to match what CI actually tests
  (Ruby 3.0–3.2 are end-of-life); `bug_tracker_uri` and `documentation_uri`
  metadata are added; and `spec.files` ships `CHANGELOG.md` and the gemspec
  itself alongside the code, README and LICENSE.

### Fixed

- The documented Ruby 4.0.x install workaround now leads with fixing the
  environment (`gem install rbs -v '>= 4.0.0'`), with `--no-document` as a
  fallback — the rbs upgrade actually makes the plain `gem install letsdo`
  post-install RDoc hook succeed instead of just skipping it. The CI
  "Verify install" step now installs the built gem without `--no-document`,
  repairs a broken rdoc/rbs pair when `require "rdoc"` fails, runs on Ruby
  4.0 as well as 3.3, and checks `letsdo --version` — so the exact plain
  install path a user runs (including the RDoc hook) is guarded against the
  rdoc/rbs conflict crashing it again.

## [0.3.0] - 2026-09-07

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
- Quitting the TUI no longer leaves the terminal in raw mode: raw-mode entry
  moved to the main thread, so the saved termios (echo + canonical line
  editing) is restored on every quit path — the shell in a tmux pane stays
  usable.
- A tool-only agent run after a text run no longer writes a spurious blank
  line on stdout (`OutputStreamer#finish` resets its last-char state).
- `require "letsdo"` no longer eagerly loads `tty-cursor` (or any tty-* gem),
  so `rake test` runs on a clean Ruby without the gem installed; the TUI
  still loads its gems lazily on the interactive path.
- Documented a Ruby 4.0.x install note: the post-install RDoc hook can crash
  on a mismatched rdoc/rbs pair — install with `--no-document`.

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

[Unreleased]: https://github.com/sergio-fry/letsdo/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/sergio-fry/letsdo/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/sergio-fry/letsdo/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/sergio-fry/letsdo/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/sergio-fry/letsdo/releases/tag/v0.1.0
