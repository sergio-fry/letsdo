---
id: TASK-60
title: >-
  Backend selection: LETSDO_BACKEND knob + registry in Letsdo::CLI::Builder
  (default pi)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:41'
labels: []
dependencies:
  - TASK-42
  - TASK-53
  - TASK-54
  - TASK-59
references:
  - TASK-52
type: enhancement
ordinal: 49000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Second half of the TASK-52 spike (AI backend adapter seam). After TASK-59 lands, Letsdo::Backends::Pi exists behind the normalized backend protocol and Letsdo::Agent takes a backend_factory; this task makes AI backends selectable: LETSDO_BACKEND env knob (default 'pi') read at the single config point (Letsdo::Config from TASK-53), and a backend registry owned by the wiring layer (Letsdo::CLI::Builder from TASK-54). Letsdo::Agent keeps its backend_factory contract, Letsdo::AgentLoop keeps calling agent.backend.terminate_now, Letsdo::Loop and Letsdo::OutputStreamer require no change — selection happens only in the wiring. Behavior identical today: without LETSDO_BACKEND everything runs exactly as now (pi default, LETSDO_PI_COMMAND/LETSDO_PI_FLAGS work as before).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Letsdo::Config reads LETSDO_BACKEND with default 'pi' (empty/invalid value -> default), documented in its env list; README/cli docstrings list the new variable
- [ ] #2 Letsdo::CLI::Builder owns a backend registry mapping backend names to factories (BACKENDS = { 'pi' => Letsdo::Backends::Pi }); both wiring paths (plain and TUI) build the Agent's backend_factory through it with the same context as today (pi command/flags from Config, debug with LETSDO_DEBUG semantics)
- [ ] #3 Unknown LETSDO_BACKEND value fails fast: 'letsdo: unknown AI backend: <name>' on stderr and exit code 1 — no silent fallback
- [ ] #4 Injectable for tests: Builder accepts a backend factory/registry override; the in-process fake backend from TASK-59 (test/helpers/fake_backend.rb) can be switched in a unit test and the loop/CLI behaves identically; existing cli_test fake_pi tests pass unchanged (LETSDO_PI_COMMAND set, no LETSDO_BACKEND -> pi default path)
- [ ] #5 Letsdo::Agent and Letsdo::AgentLoop keep the backend-factory contract from TASK-59 unchanged; termination via agent.backend works in plain and TUI mode with the same Letsdo::Stopped unwind
- [ ] #6 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35)
<!-- AC:END -->
