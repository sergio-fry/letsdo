---
id: TASK-60
title: >-
  Backend selection: LETSDO_BACKEND knob + registry in Letsdo::CLI::Builder
  (default pi)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 07:41'
updated_date: '2026-09-10 19:37'
labels: []
dependencies:
  - TASK-42
  - TASK-53
  - TASK-54
  - TASK-59
references:
  - TASK-52
priority: medium
type: enhancement
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Second half of the TASK-52 spike (AI backend adapter seam). After TASK-59 lands, Letsdo::Backends::Pi exists behind the normalized backend protocol and Letsdo::Agent takes a backend_factory; this task makes AI backends selectable: LETSDO_BACKEND env knob (default 'pi') read at the single config point (Letsdo::Config from TASK-53), and a backend registry owned by the wiring layer (Letsdo::CLI::Builder from TASK-54). Letsdo::Agent keeps its backend_factory contract, Letsdo::AgentLoop keeps calling agent.backend.terminate_now, Letsdo::Loop and Letsdo::OutputStreamer require no change — selection happens only in the wiring. Behavior identical today: without LETSDO_BACKEND everything runs exactly as now (pi default, LETSDO_PI_COMMAND/LETSDO_PI_FLAGS work as before).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Letsdo::Config reads LETSDO_BACKEND with default 'pi' (empty/invalid value -> default), documented in its env list; README/cli docstrings list the new variable
- [x] #2 Letsdo::CLI::Builder owns a backend registry mapping backend names to factories (BACKENDS = { 'pi' => Letsdo::Backends::Pi }); both wiring paths (plain and TUI) build the Agent's backend_factory through it with the same context as today (pi command/flags from Config, debug with LETSDO_DEBUG semantics)
- [x] #3 Unknown LETSDO_BACKEND value fails fast: 'letsdo: unknown AI backend: <name>' on stderr and exit code 1 — no silent fallback
- [x] #4 Injectable for tests: Builder accepts a backend factory/registry override; the in-process fake backend from TASK-59 (test/helpers/fake_backend.rb) can be switched in a unit test and the loop/CLI behaves identically; existing cli_test fake_pi tests pass unchanged (LETSDO_PI_COMMAND set, no LETSDO_BACKEND -> pi default path)
- [x] #5 Letsdo::Agent and Letsdo::AgentLoop keep the backend-factory contract from TASK-59 unchanged; termination via agent.backend works in plain and TUI mode with the same Letsdo::Stopped unwind
- [x] #6 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Update Letsdo::Config to read LETSDO_BACKEND with default 'pi', empty/invalid -> default.
2. Update docs/config.md to document LETSDO_BACKEND in the environment variables table and add where it is read.
3. Update README.md env table to include LETSDO_BACKEND.
4. Update Letsdo::CLI::Builder to own a backend registry (default: { 'pi' => factory that builds Letsdo::Backends::Pi with pi command/flags from Config }).
   - The registry is injectable via constructor for tests.
   - Agent's backend_factory is obtained from the registry using LETSDO_BACKEND.
   - Unknown LETSDO_BACKEND results in fast failure with message "letsdo: unknown AI backend: <name>" and exit code 1.
5. Ensure Letsdo::Agent and Letsdo::AgentLoop keep the backend-factory contract unchanged.
6. Run tests to verify everything passes and rubocop remains clean.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: Letsdo::Config#backend reads LETSDO_BACKEND (default pi, blank -> default) with tests; Letsdo::CLI::Builder owns BACKENDS registry ({ 'pi' => factory from Config }) with injectable backend_registry, resolve_backend! fails fast ('letsdo: unknown AI backend: <name>', exit 1); both plain and TUI paths build the Agent backend_factory through the registry; Pi adapter receives config: for debug semantics; docs (README, docs/config.md, bin/letsdo) list LETSDO_BACKEND; new CliBuilderBackendTest + config tests. Running full suite + rubocop.

VERIFIED: Full test suite 267 runs, 780 assertions, 0 failures. RuboCop 0 offenses across lib/, bin/, test/. All acceptance criteria met:\n1. LETSDO_BACKEND env knob with default 'pi' — implemented in Config; reads, override, empty/whitespace fallback.\n2. BACKENDS registry owned by CLI::Builder; injectable via constructor.\n3. resolve_backend! fails fast on unknown backend ('letsdo: unknown AI backend: <name>', exit 1).\n4. Both plain and TUI paths build Agent backend_factory through the registry.\n5. Pi adapter receives config: for debug semantics consistency.\n6. README, bin/letsdo, docs/config.md all list LETSDO_BACKEND.\n7. CliBuilderBackendTest + config tests added and passing.\n8. new test_no_letsdo_backend_uses_the_pi_default_path now asserts "Hello, world!\n" after open_backlog_env fix (adding LETSDO_PI_COMMAND).

Validation passed: full Ruby test suite via ruby -Ilib -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |f| require_relative f }' completed with 267 runs, 780 assertions, 0 failures. RuboCop over lib/, bin/, test/ inspected 58 files with 0 offenses.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented LETSDO_BACKEND env knob (default 'pi') and backend registry in Letsdo::CLI::Builder. Verified with full Ruby test suite (267 runs, 780 assertions, 0 failures) and rubocop (0 offenses over lib/, bin/, test/). All acceptance criteria met.
<!-- SECTION:FINAL_SUMMARY:END -->
