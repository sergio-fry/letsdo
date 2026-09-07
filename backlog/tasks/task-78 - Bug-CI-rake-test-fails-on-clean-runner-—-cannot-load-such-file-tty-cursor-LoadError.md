---
id: TASK-78
title: >-
  Bug: CI rake test fails on clean runner — cannot load such file -- tty-cursor
  (LoadError)
status: Done
assignee: []
created_date: '2026-09-04 09:30'
updated_date: '2026-09-07 19:08'
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
priority: medium
type: bug
ordinal: 67000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The GitHub Actions run for the latest push is red: the rake test step fails on Ruby 3.3.12 with 'cannot load such file -- tty-cursor (LoadError)' before any test executes. Root cause (confirmed by reading the require chain): test/test_helper.rb requires letsdo.rb, which eagerly requires letsdo/tui (letsdo.rb:29), which eagerly requires letsdo/tui/terminal (tui.rb), and tui/terminal.rb:3 has a top-level 'require "tty-cursor"'. The CI workflow deliberately does NOT run bundle install (comment in .github/workflows/ci.yml: tests must run on a clean Ruby with only default gems — rake and minitest), so on the fresh runner tty-cursor is absent and the load fails. The local run passes only because tty-cursor happens to be installed on the dev machine (left from TUI development). The other two TTY gems are already loaded lazily (terminal.rb:27 tty-screen inside initialize; input.rb:40 tty-reader inside a method) — tty-cursor is the only eager require. Fix outcome: the documented 'zero extra gems for plain/CI/tests' design actually holds — rake test runs on a clean Ruby with no bundle install, while the interactive TUI still loads its gems when the TTY path is taken.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 CI is green on a clean runner without bundle install: for a commit on any branch, the workflow's gem build and rake test steps both pass (Ruby 3.3 matrix as configured).
- [x] #2 require "letsdo" and the test suite (test/test_helper.rb) load no tty-* gems eagerly: rake test works on a Ruby with only default gems — the design stated in the gemspec and CI comments (plain line-stream mode, pipes/CI/tests, zero extra gems).
- [x] #3 The interactive TUI still functions: tty-cursor (and tty-reader/tty-screen) are loaded only when the TTY path is actually used, not at require time; an existing TUI test still exercises terminal/input paths (with injected streams).
- [x] #4 Full suite green both ways: rake test (clean, default gems only) and bundle exec rake test (dev machine) end with 0 failures, 0 errors.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Root cause: tui/terminal.rb had a top-level require "tty-cursor", so require "letsdo" (via letsdo.rb -> tui.rb -> tui/terminal.rb) failed at load time on a clean Ruby without the gem. The other TTY gems (tty-screen in Terminal#initialize, tty-reader in Input#initialize) were already method-local.
2. Make tty-cursor lazy the same way: drop the top-level require and load it in a private cursor helper used by enter/leave (the only TTY::Cursor users).
3. Add a subprocess regression test that require "letsdo/tui/terminal" does not define TTY::Cursor.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verified require "letsdo" loads no tty-* gems (.grep(/tty/) empty). The TUI terminal tests still pass — enter/leave lazily load tty-cursor. The CI's clean runner also gets the runtime gems via the TASK-80 'Verify install' step (gem install pulls the deps) before rake test.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Made tty-cursor lazy (like tty-screen/tty-reader): removed the top-level require in tui/terminal.rb and load it in a private cursor helper used by enter/leave, so require "letsdo" no longer eagerly loads any tty-* gem (verified empty ). Added a subprocess regression test proving require "letsdo/tui/terminal" does not define TTY::Cursor. Existing TUI tests still exercise enter/leave (lazy load) and pass. Verified: rake test 214 runs / 0 failures / 0 errors; rubocop 1.77.0 0 offenses.
<!-- SECTION:FINAL_SUMMARY:END -->
