---
id: TASK-71
title: 'letsdo doctor: environment self-check command'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 08:14'
updated_date: '2026-09-13 14:03'
labels: []
dependencies:
  - TASK-53
priority: medium
type: enhancement
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
A newcomer needs one command that reports exactly what is broken in their environment and how to fix it. Today a missing `pi` on PATH raises a full Ruby backtrace, and a missing or empty `backlog/` makes the loop retry forever with no reason and no hint. Add `letsdo doctor` — an environment self-check that prints one line per check with a status tag and an actionable hint for every failure/warning, and exits 0 when nothing FAILs, 1 otherwise.

Note: the backend-missing case is already handled — `PiRunner` raises `Letsdo::BackendUnavailableError` and the CLI prints a clear message and exits 2 (no backtrace). This task adds only the `doctor` command; pointing the loop's "backlog unavailable" message at `letsdo doctor` is tracked separately.

Checks (one line each):
- ruby version >= 3.3 (RUBY_VERSION) — OK / WARN
- pi command on PATH (LETSDO_PI_COMMAND, default `pi`) — OK / FAIL
- backlog command on PATH (LETSDO_BACKLOG_COMMAND, default `backlog`) — OK / FAIL
- project root (LETSDO_ROOT, default pwd) has `backlog/` with `tasks/` — OK / FAIL
- AGENTS.md present at root — OK / WARN
- agents/ present and non-empty — OK / WARN (hint: `letsdo <name> --init`)
- stdout is a TTY — INFO (TUI vs plain mode)

All env values come from `Letsdo::Config` (no new direct ENV reads). `doctor` becomes a reserved agent name (documented in README + bin/letsdo header); `--version`/`--help` keep priority; unknown options still exit 1.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `letsdo doctor` prints one line per check with a status tag ([ OK ] / [WARN] / [FAIL] / [INFO]) and an actionable hint for every FAIL and WARN; exits 0 when there is no FAIL line, 1 otherwise
- [x] #2 Checks cover at least: ruby version vs >= 3.3, pi on PATH (LETSDO_PI_COMMAND override honored), backlog on PATH (LETSDO_BACKLOG_COMMAND override honored), backlog/ with tasks/ under LETSDO_ROOT (default pwd), AGENTS.md (WARN), agents/ non-empty (WARN with `--init` hint), stdout TTY (INFO)
- [x] #3 All env values come from Letsdo::Config: no new direct ENV reads in the new code
- [x] #4 `--version`/`--help` keep priority and unknown options still exit 1; an agent named `doctor` is reserved (README + bin/letsdo header) and cannot be run by name
- [x] #5 Tests: Minitest with fake pi/backlog via env and a temp project root, covering everything-present / pi missing / backlog missing / no backlog dir / no AGENTS.md / no agents / non-TTY stdout. rake test 0 failures; rubocop 0 offenses; all texts English (TASK-35)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add Config#path (PATH from the injected env) so doctor code performs no direct ENV reads.
2. Add lib/letsdo/doctor/checks.rb + lib/letsdo/doctor.rb: seven checks (ruby >= 3.3, pi on PATH, backlog on PATH, backlog/tasks under root, AGENTS.md, non-empty agents/, stdout TTY), each a status tag + actionable hint for FAIL/WARN; exit 0 when no FAIL else 1.
3. Add lib/letsdo/cli/doctor.rb (CLIDoctor) wired into CLI#run right after the no-arg check and before --init; keep version/help priority and unknown-option exit 1; store env/stdin on CLI for doctor assembly.
4. Require doctor from lib/letsdo.rb.
5. Document the reserved doctor name in README (CLI reference + section) and bin/letsdo header; add usage docs.
6. Add test/doctor_test.rb (Minitest, temp root, fake pi/backlog via env) covering all-present, pi missing, backlog missing, no backlog dir, no AGENTS.md, no agents, non-TTY stdout; run rake test and rubocop.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented lib/letsdo/doctor.rb (Letsdo::Doctor) + lib/letsdo/doctor/checks.rb (7 checks, status tag + hint per FAIL/WARN) + lib/letsdo/cli/doctor.rb (CLIDoctor dispatch, wired after the no-arg check and before --init). Added Config#path (PATH from the injected env) so doctor performs no direct ENV reads; added the require + README/usage/CHANGELOG/bin header docs for the reserved doctor name.

Verification: `ruby -Ilib -Itest test/doctor_test.rb` -> 12 runs, 54 assertions, 0 failures. `rake test` -> 368 runs, 1082 assertions, 0 failures, 0 errors. `rubocop --no-server lib bin test` with the CI-pinned 1.77.0 and with local 1.90.0 -> 77 files, no offenses. Manual: `ruby -Ilib -e 'require "letsdo"; exit Letsdo::CLI.run(["doctor"])'` in the healthy repo prints 7 lines and exits 0; in a root without backlog/tasks it prints [FAIL] + hint and exits 1; missing pi/backlog names the env var to set. `gem build letsdo.gemspec --output /tmp/...` succeeds and the data tarball contains the three new files.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added `letsdo doctor`: a Letsdo::Doctor self-check (lib/letsdo/doctor.rb + doctor/checks.rb) with seven checks (ruby >= 3.3, pi on PATH, backlog on PATH, backlog/tasks under LETSDO_ROOT, AGENTS.md, non-empty agents/, stdout TTY). Each check prints one line with a [ OK ]/[WARN]/[FAIL]/[INFO] tag and an actionable hint on FAIL/WARN; exit 0 unless a check FAILs, then 1. A new Config#path exposes PATH from the injected env so doctor performs no direct ENV reads. CLI gains a CLIDoctor dispatch (doctor is reserved and never launches an agent; --version/--help keep priority, unknown options still exit 1). README, bin/letsdo header, docs/usage.md and CHANGELOG document the command. Verified with test/doctor_test.rb (12 runs/54 assertions, all seven scenarios), full rake test (368 runs, 0 failures), rubocop 1.77.0 and 1.90.0 (0 offenses), a gem build, and manual runs showing the tags, hints and 0/1 exit codes.
<!-- SECTION:FINAL_SUMMARY:END -->
