---
id: TASK-78
title: >-
  Bug: CI rake test fails on clean runner — cannot load such file -- tty-cursor
  (LoadError)
status: To Do
assignee: []
created_date: '2026-09-04 09:30'
labels: []
dependencies: []
references:
  - .github/workflows/ci.yml
  - lib/letsdo.rb
  - lib/letsdo/tui.rb
  - lib/letsdo/tui/terminal.rb
  - lib/letsdo/tui/input.rb
  - test/test_helper.rb
  - letsdo.gemspec
type: bug
ordinal: 67000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The GitHub Actions run for the latest push is red: the rake test step fails on Ruby 3.3.12 with 'cannot load such file -- tty-cursor (LoadError)' before any test executes. Root cause (confirmed by reading the require chain): test/test_helper.rb requires letsdo.rb, which eagerly requires letsdo/tui (letsdo.rb:29), which eagerly requires letsdo/tui/terminal (tui.rb), and tui/terminal.rb:3 has a top-level 'require "tty-cursor"'. The CI workflow deliberately does NOT run bundle install (comment in .github/workflows/ci.yml: tests must run on a clean Ruby with only default gems — rake and minitest), so on the fresh runner tty-cursor is absent and the load fails. The local run passes only because tty-cursor happens to be installed on the dev machine (left from TUI development). The other two TTY gems are already loaded lazily (terminal.rb:27 tty-screen inside initialize; input.rb:40 tty-reader inside a method) — tty-cursor is the only eager require. Fix outcome: the documented 'zero extra gems for plain/CI/tests' design actually holds — rake test runs on a clean Ruby with no bundle install, while the interactive TUI still loads its gems when the TTY path is taken.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 CI is green on a clean runner without bundle install: for a commit on any branch, the workflow's gem build and rake test steps both pass (Ruby 3.3 matrix as configured).
- [ ] #2 require "letsdo" and the test suite (test/test_helper.rb) load no tty-* gems eagerly: rake test works on a Ruby with only default gems — the design stated in the gemspec and CI comments (plain line-stream mode, pipes/CI/tests, zero extra gems).
- [ ] #3 The interactive TUI still functions: tty-cursor (and tty-reader/tty-screen) are loaded only when the TTY path is actually used, not at require time; an existing TUI test still exercises terminal/input paths (with injected streams).
- [ ] #4 Full suite green both ways: rake test (clean, default gems only) and bundle exec rake test (dev machine) end with 0 failures, 0 errors.
<!-- AC:END -->
