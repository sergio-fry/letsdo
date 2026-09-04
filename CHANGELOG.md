# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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