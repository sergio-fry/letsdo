---
id: TASK-54
title: >-
  Letsdo::CLI: separate argument parsing from component wiring
  (Letsdo::CLI::Builder)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:31'
updated_date: '2026-09-04 10:27'
labels: []
dependencies:
  - TASK-42
priority: medium
ordinal: 43000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Part of the TASK-50 refactoring proposal (Phase 1). Letsdo::CLI currently mixes three responsibilities: argv parsing/usage/exit codes, env config (moves to TASK-53 Letsdo::Config), and object wiring — run_agent_plain/run_agent_tui assemble streamer, agent, backlog provider, loop and the whole TUI (log, metrics, terminal, input, session, refresh proc) plus TUI-mode detection. Split parsing from wiring: Letsdo::CLI keeps the argv contract and usage; a new Letsdo::CLI::Builder owns all assembly and TUI detection; CLI.run stays the facade. Both halves become independently testable, and the wiring will grow with TASK-44 (--init), TASK-51/52 (provider/backend selection) without bloating the parser. Behavior identical: same argv handling, same exit codes, same plain output.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Letsdo::CLI keeps exactly the current argv contract: nil argv prints usage to stderr exit 1; --version/--help exit 0; an unknown option prints the error + usage exit 1; <name> runs the agent
- [ ] #2 New lib/letsdo/cli/builder.rb (Letsdo::CLI::Builder) owns all component assembly: plain path (OutputStreamer, Agent, BacklogTasks provider, AgentLoop wiring), TUI path (Tui::LogBuffer, Tui::Metrics, terminal, input, streamer-with-log, Tui::Session, refresh proc) and TUI-mode detection (stdout.tty? && stdin.tty? && TERM != dumb); Letsdo::CLI delegates to it
- [ ] #3 Behavior identical: existing cli_test.rb (incl. TUI engage / not-engage tests) passes unchanged with the same injected env/stdout/stderr/stdin; no new env vars, no exit-code changes
- [ ] #4 If TASK-44 (--init) has landed by then, letsdo --init paths keep working unchanged; the argv[0] branch structure remains the single source of truth for parsing
- [ ] #5 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35)
- [ ] #6 Affected letsdo components covered: lib/letsdo/cli.rb (shrinks to parsing), new lib/letsdo/cli/builder.rb, lib/letsdo.rb (require), tests (cli_test.rb and builder tests)
<!-- AC:END -->
