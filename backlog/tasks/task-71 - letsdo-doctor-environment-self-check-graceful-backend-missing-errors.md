---
id: TASK-71
title: 'letsdo doctor: environment self-check + graceful backend-missing errors'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:14'
updated_date: '2026-09-04 10:27'
labels: []
dependencies:
  - TASK-53
  - TASK-43
  - TASK-44
priority: medium
type: enhancement
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Analyze-first: spike TASK-64 (comments 'AC#2 DOCTOR...' and 'AC#3 SCAFFOLD SCOPE DECISION'). Implement letsdo doctor — an environment self-check report — plus run-path hardening that turns today's two broken-onboarding failure modes into actionable messages. Today (verified TASK-64): (a) pi missing on PATH -> PiRunner#run Process.spawn raises Errno::ENOENT unhandled -> full Ruby backtrace, exit 1; (b) backlog CLI missing / no backlog/ -> BacklogTasks nil -> AgentLoop prints 'letsdo: backlog unavailable, retrying in 10s' forever, no reason and no hint. Purpose: a newcomer runs 'letsdo doctor' and gets exactly which check fails plus the fix command.

What to implement (design in TASK-64 comments, AC#2):
1. NEW lib/letsdo/doctor.rb: Letsdo::Doctor — one-line report per check, status [ OK ] / [WARN] / [FAIL] / [INFO] + label + actionable hint on FAIL/WARN. Checks: ruby version info vs >= 3.0 (RUBY_VERSION); pi command resolution (LETSDO_PI_COMMAND, default 'pi') found on PATH and executable; backlog command resolution (LETSDO_BACKLOG_COMMAND, default 'backlog') found on PATH; project root (LETSDO_ROOT, default pwd) has backlog/ with tasks/ (FAIL hint: 'backlog init --agent-instructions agents'); AGENTS.md present (WARN); agents/ present and non-empty (WARN — runs still work via the TASK-43 fallback; hint 'letsdo <name> --init'); stdout TTY (INFO — TUI vs plain mode). Exit code 0 when no FAIL, 1 otherwise.
2. Letsdo::CLI: 'letsdo doctor' recognized before agent-name lookup (argv[0] == 'doctor'); report to stdout, exit per above; --version/--help keep priority; unknown options unchanged. 'doctor' becomes a reserved agent name — document it (bin/letsdo header, README).
3. Run-path hardening: PiRunner#run rescues Errno::ENOENT on spawn -> raise Letsdo::BackendMissingError (NEW in lib/letsdo/errors.rb, keeps Letsdo::Error base) with the command name; CLI prints message + hint to stderr and exits 1 — no Ruby backtrace. AgentLoop: when the FIRST provider call of a run returns nil, extend the line once to: letsdo: backlog unavailable, retrying in Ns — run 'letsdo doctor' to diagnose (single-quoted hint inside the message); later nils keep today's line.
4. Env values come from Letsdo::Config (TASK-53) — the doctor task depends on it so config/validation stays in one place (spike constraint). Coordinate the cli.rb diffs with TASK-43 (notification) and TASK-44 (--init) — see their descriptions; the doctor task lands after them (deps set).
5. bin/letsdo header + README: document 'letsdo doctor', the reserved 'doctor' name, and a 'Troubleshooting' section pointing at it.

Constraints: TASK-35 (all texts English), TASK-37 (rubocop 0 offenses), TASK-39 (loop shape untouched), TASK-42 merge state, tests stay Minitest with the fixtures fake_pi/fake_backlog and StringIO stdio injection (test/cli_test.rb conventions). No letsdo new, no prompt variants, no first-run banner (decided OUT of scope in TASK-64 AC#3).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 'letsdo doctor' prints one line per check with a status tag ([ OK ]/[WARN]/[FAIL]/[INFO]) and, for every FAIL and WARN, an actionable hint naming the fix command or variable; exits 0 when no FAIL line, 1 otherwise (verified with a temp project root, fake pi/backlog commands via env, and scenarios: everything present / pi missing / backlog missing / no backlog dir / no AGENTS.md / no agents / non-TTY stdout)
- [ ] #2 Checks cover at least: ruby version vs >= 3.0 (RUBY_VERSION), pi command on PATH (LETSDO_PI_COMMAND override honored), backlog command on PATH (LETSDO_BACKLOG_COMMAND override honored), backlog/ with tasks/ under LETSDO_ROOT (default pwd), AGENTS.md at root (WARN), agents/ present and non-empty (WARN with --init hint), stdout TTY (INFO)
- [ ] #3 Runs with a missing backend: LETSDO_PI_COMMAND pointing at a nonexistent path -> Letsdo::BackendMissingError raised by PiRunner on spawn, CLI prints the actionable message (mentions the command and the variable) to stderr and exits 1 with NO Ruby backtrace (tests: pi_runner_test + cli_test)
- [ ] #4 First provider-nil in a run extends the wait message once with the doctor hint ('run letsdo doctor to diagnose'); subsequent nils print today's short line; asserted in agent_loop/cli tests
- [ ] #5 'letsdo doctor' keeps --version/--help priority and unknown options still exit 1; an agent named 'doctor' is documented as reserved (README + bin/letsdo header) and cannot be run by name
- [ ] #6 All env values come from Letsdo::Config (TASK-53): no new direct ENV reads in the new code; rake test green (0 failures); rubocop on lib/, bin/, test/ — 0 offenses; all texts in English (TASK-35)
<!-- AC:END -->
