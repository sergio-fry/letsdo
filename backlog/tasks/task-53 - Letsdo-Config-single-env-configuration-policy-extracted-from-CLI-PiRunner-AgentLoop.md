---
id: TASK-53
title: >-
  Letsdo::Config: single env configuration policy (extracted from
  CLI/PiRunner/AgentLoop)
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:31'
updated_date: '2026-09-04 10:27'
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
- [ ] #1 New lib/letsdo/config.rb: Letsdo::Config reads every env variable with exactly today's defaults and precedence: LETSDO_ROOT (default Dir.pwd), LETSDO_PI_FLAGS with AGENT_PI_FLAGS fallback, AGENT_ASSIGNEE_HANDLE (default @<name>), LETSDO_WAIT_SECONDS with AGENT_WAIT_SECONDS fallback (default 10.0; invalid values fall back to the default), LETSDO_PI_COMMAND (default pi), LETSDO_BACKLOG_COMMAND (default backlog), LETSDO_DEBUG (nil -> ENV check preserved); env hash injectable for tests, defaulting to ENV
- [ ] #2 Letsdo::CLI, Letsdo::PiRunner and Letsdo::AgentLoop consume the config; no direct ENV reads remain in lib/ (grep for ENV[ matches lib/letsdo/config.rb only, plus documentation comments)
- [ ] #3 Plain non-TTY behavior byte-identical: existing cli/agent_loop/pi_runner/output_streamer tests pass unchanged; LETSDO_DEBUG=1 still enables [letsdo] traces in both PiRunner and AgentLoop
- [ ] #4 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all new texts in English (TASK-35)
- [ ] #5 Affected letsdo components covered: new lib/letsdo/config.rb, lib/letsdo/cli.rb, lib/letsdo/pi_runner.rb, lib/letsdo/agent_loop.rb, lib/letsdo.rb (require), tests
<!-- AC:END -->
