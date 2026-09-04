---
id: TASK-64
title: >-
  Spike: strengthen onboarding/bootstrap (env self-check, prompt setup, doctor,
  scaffold)
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 08:01'
updated_date: '2026-09-04 08:15'
labels: []
dependencies:
  - TASK-43
  - TASK-44
type: spike
ordinal: 53000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Analyze how to strengthen letsdo onboarding/bootstrap (per user request): today setup means manual steps (backlog init, AGENTS.md, agents/<name>.md prompts). TASK-43 adds a built-in default prompt (run without a prompt file), TASK-44 adds letsdo <name> --init (starter prompt file). This spike goes beyond them: a first-run diagnostic/self-check (pi/backend binary present and runnable, backlog CLI installed, project has backlog/ + AGENTS.md, TTY detection), failure hints with actionable fixes, and possibly a scaffold (letsdo new / letsdo doctor) so a new repo is usable in one command pair.

Scope suggestions to evaluate (verify against current code, propose precise set): letsdo doctor (environment health report, exit code semantics), first-run guide message, --init extension (default prompt variants, missing-file hints), project scaffold (backlog init + AGENTS.md + agents/ skeleton), README quickstart alignment (TASK-46). Coordinate with TASK-53 (Letsdo::Config) so config/validation lives in one place. Deliverable: requirements + design in comments + developer tasks (@developer) with ACs. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Current onboarding gaps mapped (steps a newcomer must do manually: install pi, install backlog CLI, backlog init, AGENTS.md, prompts, run) with what TASK-43/44 already cover
- [x] #2 Doctor/self-check requirements specified: checks list (pi executable, backlog CLI, backlog/ + AGENTS.md present, agents/ resolvable, stdout TTY), exit codes, actionable hints
- [x] #3 Scaffold scope decided (letsdo new vs extending --init): what gets created (backlog init, AGENTS.md, agents/ skeleton, .gitignore hints) and what is out of scope
- [x] #4 Developer task(s) created via backlog CLI (@developer) with ACs, sized for single-PR; spike leaves code untouched
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify current state: CLI arg handling, PromptStore/PiRunner/BacklogTasks failure behavior, backlog CLI init/doctor surface, README onboarding text (TASK-46), TASK-43/44 scope. 2. Map onboarding gaps (what TASK-43/44 cover, what remains: unhandled ENOENT on missing pi, generic 'backlog unavailable' loop, no self-check). 3. Spec letsdo doctor: checks list, line format, exit codes, hints; run-path hardening (BackendMissingError). 4. Decide scaffold scope: no letsdo new (backlog init owns it); --init covers prompts; doctor gives hints. 5. Create one @developer task with ACs. 6. Verify ACs, final summary, Done, commit backlog folder.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
State verified 2026-09-04 (TASK-64): pi missing -> Errno::ENOENT from PiRunner#run Process.spawn crashes with Ruby backtrace; backlog CLI missing/no backlog/ -> BacklogTasks#call nil -> AgentLoop prints 'letsdo: backlog unavailable, retrying in 10s' forever (no hint); backlog init exists (interactive git prompt, --agent-instructions agents writes AGENTS.md); backlog doctor = duplicate-ID repair, NOT an env check; README (TASK-46) already documents TASK-43/44 fallback + --init. TASK-43/44 are @developer tasks (deps of this spike's future doctor task for cli.rb merge order).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-04 08:14
---
AC#1 ONBOARDING GAP MAP (verified 2026-09-04 against current code).

Steps a newcomer must do manually to run letsdo (checked against lib/letsdo/*):
1. Install Ruby >= 3.0 (gemspec required_ruby_version; CI runs 3.3).
2. Install the pi CLI on PATH (LETSDO_PI_COMMAND default 'pi').
3. Install the backlog CLI on PATH (LETSDO_BACKLOG_COMMAND default 'backlog').
4. backlog init in the project dir -> creates backlog/ + subfolders. Note: interactive (asks a git question); 'backlog init --agent-instructions agents' additionally writes AGENTS.md.
5. AGENTS.md (the Backlog.md workflow nudge for agents) - optional for letsdo itself, but agents lose the task-work protocol without it.
6. Create agents/<name>.md prompt (or add agents/ dir).
7. Run 'letsdo <name>'.

What TASK-43/44 already cover (designed in TASK-41): step 6 - missing prompt file -> built-in default prompt + one-time stderr notification with the exact probed path + '--init' hint; 'letsdo <name> --init' materializes agents/<name>.md. So the prompt gap is COVERED by 43/44; doctor must not duplicate it.

Verified remaining gaps (evidence):
a) pi missing on PATH -> PiRunner#run (lib/letsdo/pi_runner.rb) Process.spawn raises Errno::ENOENT unhandled -> full Ruby backtrace, exit 1. Worst UX gap.
b) backlog CLI missing (or no backlog/ in cwd, or LETSDO_ROOT wrong) -> BacklogTasks#call rescues ENOENT/JSON::ParserError -> nil -> AgentLoop prints 'letsdo: backlog unavailable, retrying in 10s' forever. Works but silent: no reason, no hint, process never exits on its own. Ran 'backlog task list' outside a project: stderr message 'No Backlog.md project found. Run backlog init to initialize.' -> non-JSON stdout -> provider nil (confirmed).
c) No overall self-check: a newcomer cannot discover which of the above is broken without reading source.
d) Non-TTY stdout -> plain mode by design; NOT a gap (TUI engages only on tty stdin+stdout and TERM != dumb; confirmed in CLI#tui?).

Decision: this spike's deliverable is a 'letsdo doctor' self-check (AC#2) + run-path hardening for (a), NOT a first-run banner (the 43/44 notification already covers the prompt case; doctor is the on-demand diagnosis mechanism).
---

author: @analyst
created: 2026-09-04 08:14
---
AC#2 DOCTOR/self-check requirements.

Command: 'letsdo doctor' - a report command (plain-line, stdout), recognized before agent-name lookup (argv[0] == 'doctor'); --version/--help keep priority when argv[0]. 'doctor' becomes a RESERVED agent name (documented in bin/letsdo header + README; an agents/doctor.md cannot be run by name).

Checks (each = one line, status + label + hint where relevant):
[INFO] ruby: <RUBY_VERSION> (requires >= 3.0)
[ OK ] pi: <resolved command> (LETSDO_PI_COMMAND default 'pi') found on PATH and executable
[FAIL] pi: not found - install pi (per README Requirements) or set LETSDO_PI_COMMAND
[ OK ] backlog: <resolved command> (LETSDO_BACKLOG_COMMAND default 'backlog') found on PATH
[FAIL] backlog: not found - install the Backlog.md CLI or set LETSDO_BACKLOG_COMMAND
[ OK ] project: backlog/ with tasks/ under <LETSDO_ROOT|pwd>
[FAIL] project: no backlog/ - run 'backlog init --agent-instructions agents' in <root>
[WARN] project: AGENTS.md missing at <root> - agents lose the task-work protocol; create it (e.g. via backlog init --agent-instructions agents)
[WARN] agents/: missing or empty at <root>/agents - runs still work via the built-in default prompt (TASK-43); create prompts with 'letsdo <name> --init'
[INFO] tty: stdout is a terminal -> TUI mode; not a terminal -> plain line-stream mode

Exit codes: 0 = no FAIL lines (WARN/INFO allowed); 1 = at least one FAIL. Matches the CLI contract (0 success / 1 error), CI-usable.

Where checks get their values: Letsdo::Config (TASK-53) - the single env policy owner. Doctor task DEPENDS on TASK-53 so config/validation stays in one place (spike constraint). No agent name argument: report is name-less; the assignee query is exercised at run time, and its nil case gets the doctor hint (see run-path hardening).

Run-path hardening (same task, one coherent PR):
1. PiRunner#run: rescue Errno::ENOENT on spawn -> raise Letsdo::BackendMissingError(command) (new, in errors.rb) with an actionable message; CLI prints it to stderr + exit 1, no backtrace.
2. AgentLoop: on the FIRST provider-nil of a run print 'letsdo: backlog unavailable, retrying in Ns - run letsdo doctor to diagnose' once (later nils keep today's shorter line).

Test conventions (from test/cli_test.rb, test/fixtures/fake_pi, fake_backlog): StringIO stdio injection, LETSDO_PI_COMMAND/LETSDO_BACKLOG_COMMAND env overrides, FAKE_PI_ARGV_FILE argv assertions, Minitest only.
---

author: @analyst
created: 2026-09-04 08:14
---
AC#3 SCAFFOLD SCOPE DECISION.

Evaluated candidates (the spike's scope suggestions):
- 'letsdo new' project scaffold: REJECTED for now. Reason: backlog init already owns project initialization (creates backlog/ + folders; --agent-instructions agents writes AGENTS.md); letting letsdo duplicate it splits one workflow across two CLIs and would have to replicate the interactive git question. Doctor's FAIL hint carries the exact command pair (backlog init --agent-instructions agents, then letsdo <name> --init) - one command pair, no new surface. Revisit only if users report friction.
- '--init extension' (prompt variants / missing-file hints): NOT extended. TASK-44 already defines --init existence/overwrite/unsafe-name semantics with DefaultPrompt::TEXT as the single template; variants are settings - out of scope (TASK-41 precedent: 'settings later, text only').
- First-run guide message: REPLACED by doctor. The TASK-43 one-time notification covers the prompt case; everything else is diagnosed on demand via 'letsdo doctor' - no extra banner to maintain.
- .gitignore hints: OUT of scope (backlog init manages its own artifacts; agents/ is user content).
- README quickstart alignment (TASK-46): already aligned for TASK-43/44 (verified: README documents the fallback notification and --init). Only addition: a 'Troubleshooting' section for letsdo doctor (included in the developer task).

IN SCOPE (one developer task, single PR): Letsdo::Doctor + run-path hardening (AC#2). OUT OF SCOPE: letsdo new, prompt variants, first-run banner, .gitignore, README rewrite.
---

author: @analyst
created: 2026-09-04 08:15
---
AC#4 DEVELOPER TASK CREATED. TASK-71 'letsdo doctor: environment self-check + graceful backend-missing errors' (@developer, enhancement, deps TASK-53/43/44): description carries the full design (Letsdo::Doctor check list + line format + exit codes, CLI wiring incl. reserved 'doctor' name, BackendMissingError run-path hardening, first-nil doctor hint, Config integration, README Troubleshooting), 6 testable ACs, affected letsdo components listed (new lib/letsdo/doctor.rb, errors.rb, pi_runner.rb, agent_loop.rb, cli.rb, lib/letsdo.rb, bin/letsdo header, README, tests). Sized for a single PR. Spike left code untouched: no edits to lib/, bin/, test/ this run. Scaffold decision (no letsdo new) recorded in the AC#3 comment - pure-decision, no implementation task needed.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike completed: onboarding/bootstrap analysis for letsdo. Mapped the manual onboarding steps and verified the remaining gaps in code (unhandled Errno::ENOENT on missing pi -> backtrace; generic 'backlog unavailable, retrying' loop with no hint for missing backlog CLI/backlog dir; TASK-43/44 already cover the prompt gap). Specified 'letsdo doctor' (checks, [ OK ]/[WARN]/[FAIL]/[INFO] line format, exit 0/1 semantics, actionable hints, reserved 'doctor' name) plus run-path hardening (Letsdo::BackendMissingError on spawn ENOENT, first-provider-nil doctor hint). Decided scaffold scope: no 'letsdo new' (backlog init owns project init), no prompt variants, no first-run banner, no .gitignore. Created TASK-71 for @developer (deps TASK-53/43/44, 6 ACs, single-PR). Evidence: comments AC#1-AC#4 on this task, TASK-71 view; verified against lib/letsdo/{cli,pi_runner,backlog_tasks,agent_loop,loop,prompt_store}.rb, README (TASK-46), backlog CLI init/doctor surface; repo untouched (spike), only backlog files committed.
<!-- SECTION:FINAL_SUMMARY:END -->
