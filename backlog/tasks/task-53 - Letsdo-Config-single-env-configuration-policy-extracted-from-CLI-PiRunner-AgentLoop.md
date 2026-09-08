---
id: TASK-53
title: >-
  Letsdo::Config: single env configuration policy (extracted from
  CLI/PiRunner/AgentLoop)
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 07:31'
updated_date: '2026-09-08 14:17'
labels: []
dependencies:
  - TASK-42
priority: medium
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Part of the TASK-50 refactoring proposal (Phase 1). Today the env policy for LETSDO_*/AGENT_* variables is split across Letsdo::CLI (root, pi flags with AGENT_PI_FLAGS fallback, assignee handle, wait seconds with AGENT_WAIT_SECONDS fallback, pi/backlog commands, TERM) and read directly inside Letsdo::PiRunner and Letsdo::AgentLoop (LETSDO_DEBUG with nil -> ENV check in each class) — two different defaulting styles for one variable family. Extract one Letsdo::Config that reads every variable with exactly the current defaults and precedence; CLI/PiRunner/AgentLoop consume it. This makes env policy testable in one place and gives TASK-51/52 (provider/backend knobs like LETSDO_PROVIDER, LETSDO_BACKEND) a single place to add new variables. Behavior must stay identical: same env vars, same fallbacks, same exit codes, plain non-TTY output byte-identical.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 New lib/letsdo/config.rb: Letsdo::Config reads every env variable with exactly today's defaults and precedence: LETSDO_ROOT (default Dir.pwd), LETSDO_PI_FLAGS with AGENT_PI_FLAGS fallback, AGENT_ASSIGNEE_HANDLE (default @<name>), LETSDO_WAIT_SECONDS with AGENT_WAIT_SECONDS fallback (default 10.0; invalid values fall back to the default), LETSDO_PI_COMMAND (default pi), LETSDO_BACKLOG_COMMAND (default backlog), LETSDO_DEBUG (nil -> ENV check preserved); env hash injectable for tests, defaulting to ENV
- [x] #2 Letsdo::CLI, Letsdo::PiRunner and Letsdo::AgentLoop consume the config; no direct ENV reads remain in lib/ (grep for ENV[ matches lib/letsdo/config.rb only, plus documentation comments)
- [x] #3 Plain non-TTY behavior byte-identical: existing cli/agent_loop/pi_runner/output_streamer tests pass unchanged; LETSDO_DEBUG=1 still enables [letsdo] traces in both PiRunner and AgentLoop
- [x] #4 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all new texts in English (TASK-35)
- [x] #5 Affected letsdo components covered: new lib/letsdo/config.rb, lib/letsdo/cli.rb, lib/letsdo/pi_runner.rb, lib/letsdo/agent_loop.rb, lib/letsdo.rb (require), tests
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add lib/letsdo/config.rb: Letsdo::Config reads all 7 env vars with today's defaults/precedence (root, pi_flags with AGENT_PI_FLAGS fallback, assignee_handle, wait_seconds with AGENT_WAIT_SECONDS fallback + invalid->default, pi_command, backlog_command, debug?), env injectable defaulting to ENV.
2. Require config in lib/letsdo.rb (before pi_runner/agent_loop/cli).
3. CLI: build @config, delegate root/pi_flags/assignee_handle/wait_seconds/pi_command/backlog_command to it; drop DEFAULT_WAIT_SECONDS and the shellwords require; keep @env for TERM (tui?) and provider_for merge.
4. PiRunner + AgentLoop: debug now comes from a Config (opts[:debug] override preserved, default Config.new -> ENV), removing the direct ENV['LETSDO_DEBUG'] reads.
5. Add test/config_test.rb covering defaults + precedence + invalid fallback.
6. Verify: grep ENV[ hits only config.rb, rake test green, rubocop clean.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: full suite 234 runs/727 assertions, 0 failures, 0 errors (run via ruby -Ilib -Itest, bundle lacks rake). rubocop lib/ bin/ test/: 53 files, 0 offenses after extracting resolve_debug from assign_control_opts in agent_loop.rb to fix Metrics/AbcSize (18.11>17). grep confirms no ENV[ reads remain in lib/ (config.rb only, via injectable env hash). config_test.rb: 20 runs, 20 assertions, 0 failures.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extracted single env config policy into Letsdo::Config (7 variables). Fixed Metrics/AbcSize in agent_loop.rb via resolve_debug extraction. All tests pass (234/727 assertions, 0 failures). grep confirms lib/ has only config.rb reading env (injectable hash). rubocop clean (53 files, 0 offenses).
<!-- SECTION:FINAL_SUMMARY:END -->
