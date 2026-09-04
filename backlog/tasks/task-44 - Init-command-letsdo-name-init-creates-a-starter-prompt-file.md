---
id: TASK-44
title: 'Init command: letsdo <name> --init creates a starter prompt file'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 21:13'
updated_date: '2026-09-04 13:18'
labels: []
dependencies:
  - TASK-43
priority: medium
type: enhancement
ordinal: 33000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the letsdo init command: create a starter prompt file (analysis: TASK-41 — comments "SCENARIO ANALYSIS" and "DESIGN DECISIONS").

User requirement: a way to materialize the prompt file so the agent can later be customized; the command must NOT run the agent, only create agents/<name>.md with the starter default prompt.

What to implement:
1. Letsdo::PromptStore#create_agent(name, content) (lib/letsdo/prompt_store.rb): mkdir_p the agents/ dir; return false (no raise, nothing written) when the file already exists or the name is unsafe (name contains "/" or "\\", or is "." or ".."); otherwise write content and return true. Creation must never write outside agents/.
2. Letsdo::CLI (lib/letsdo/cli.rb): recognize --init in two positions — argv[0] with the name in argv[1] ('letsdo --init <name>') and argv[1] after a name ('letsdo <name> --init'). Behavior:
   - success: print "created <path>" (stdout), exit 0; file content = Letsdo::DefaultPrompt::TEXT (TASK-43);
   - file already exists: "letsdo: agents/<name>.md already exists" (stderr), exit 1, no overwrite;
   - unsafe name: "letsdo: invalid agent name: <name>" (stderr), exit 1;
   - 'letsdo --init' without a name: usage (stderr), exit 1;
   - the agent is never started (no pi spawn).
   --version/--help keep their current priority when argv[0]; unknown options keep exiting 1. Existing plain-run behavior (no --init in argv) stays as-is (TASK-43 fallback included).
3. Tests (test/cli_test.rb, test/prompt_store_test.rb): create writes exactly DefaultPrompt::TEXT and returns true / prints "created <path>" with exit 0 and does NOT spawn pi (assert the fake pi argv file is empty); existing file -> content unchanged, message, exit 1; unsafe names ("a/b", "../x") -> refused, nothing created; missing name -> usage exit 1; both --init position forms; --init is not triggered by a plain name run.
4. bin/letsdo header comment and README.md Usage section: document 'letsdo <name> --init' (creates agents/<name>.md with the starter default prompt, never runs the agent).

Requirement origin: TASK-41 (analyst spike). Constraints — TASK-35 (all texts English), TASK-37 (rubocop 0 offenses), TASK-39 (loop untouched). Depends on TASK-43 (DefaultPrompt::TEXT).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 'letsdo <name> --init' creates agents/<name>.md (mkdir_p) containing exactly Letsdo::DefaultPrompt::TEXT, prints 'created <path>', exits 0 and never starts the agent (no pi spawned in tests)
- [x] #2 'letsdo --init <name>' behaves identically to the name-first form
- [x] #3 Existing agents/<name>.md is never overwritten: message to stderr, exit 1, file content unchanged
- [x] #4 Unsafe names (containing '/', containing '\', '.' or '..') are refused with an error, exit 1; nothing is written outside agents/
- [x] #5 'letsdo --init' without a name prints usage and exits 1; --version/--help keep their priority when argv[0]; unknown options still exit 1
- [x] #6 rake test green (0 failures); rubocop on lib/, bin/, test/ — 0 offenses; README and bin/letsdo header document --init; all texts in English (TASK-35)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. PromptStore#create_agent(name, content) in lib/letsdo/prompt_store.rb: mkdir_p agents/, never raises, returns false when the name is unsafe (contains '/' or '\\', or is '.'/'..' — via a public PromptStore.unsafe_name? helper reused by the CLI) or agents/<name>.md already exists; otherwise File.write(content) and return true. Creation never writes outside agents/.
2. Letsdo::CLI#run: recognize '--init' as argv[0] (name in argv[1], missing name -> usage exit 1) and as argv[1] after a name ('letsdo <name> --init'); version/help keep their argv[0] priority, unknown argv[0] options still exit 1, plain runs unchanged. New init_agent(name): unsafe -> 'letsdo: invalid agent name: <name>' (stderr, exit 1); create_agent false -> 'letsdo: agents/<name>.md already exists' (stderr, exit 1); success -> 'created <abs path>' (stdout), exit 0. Never spawns pi.
3. Tests: prompt_store_test (create writes exact content incl. DefaultPrompt::TEXT, mkdir_p, existing -> false + content unchanged, unsafe names refused with nothing written outside agents/); cli_test new CliInitTest (success prints created <path> + exit 0 + fake pi argv file empty; existing file unchanged + message + exit 1; unsafe names refused; missing name -> usage exit 1; both --init position forms work; plain-run does not trigger --init).
4. Docs: bin/letsdo header Usage gains 'letsdo <name> --init' (creates agents/<name>.md with the starter default prompt, never runs the agent); README Usage/CLI-reference already documents --init (verify); CHANGELOG Added entry.
5. Verify: rake test green (0 failures), rubocop --no-server lib bin test 0 offenses, commit incl. backlog folder.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: rake test = 195 runs, 667 assertions, 0 failures, 0 errors. rubocop --no-server lib bin test = 48 files, no offenses. Manual smoke (bin/letsdo, LETSDO_ROOT=/tmp/smoke44): 'alpha --init' -> 'created <abs>/agents/alpha.md', exit 0, file byte-identical to Letsdo::DefaultPrompt::TEXT; repeat -> 'letsdo: agents/alpha.md already exists', exit 1, content unchanged; '--init beta' (flag-first) identical; '--init' with no name -> usage + agents list, exit 1; 'a/b --init' -> 'letsdo: invalid agent name: a/b', exit 1; '--version' still exit 0 at argv[0]. No pi spawn in --init: FAKE_PI_ARGV_FILE stays empty (test).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented the --init scaffold command. PromptStore#create_agent (lib/letsdo/prompt_store.rb): mkdir_p agents/, returns false (never raises, writes nothing) when the name is unsafe — public PromptStore.unsafe_name? refuses '/', '\\', '.', '..' — or the file already exists; otherwise writes the content and returns true; nothing is ever written outside agents/. CLI recognizes --init in both argument orders ('letsdo <name> --init' and 'letsdo --init <name>') via delegating run() to the new Letsdo::CLIInit module (lib/letsdo/cli/init.rb, the same pattern as CLILaunch — keeps the CLI class within rubocop's Metrics limits): success prints 'created <abs path>' (stdout, exit 0, content = Letsdo::DefaultPrompt::TEXT), existing file -> 'letsdo: agents/<name>.md already exists' (stderr, exit 1), unsafe name -> 'letsdo: invalid agent name: <name>' (stderr, exit 1), missing name -> usage (exit 1); the agent is never started; --version/--help keep argv[0] priority, unknown options still exit 1, plain runs (no --init) unchanged (loop untouched, TASK-39). Tests: 7 new CliInitTest cases + 7 new PromptStore cases (create writes exactly DefaultPrompt::TEXT, mkdir_p, no-spawn pi argv empty, no-overwrite, unsafe names incl. backslash, both position forms, plain run does not trigger --init, nothing created outside agents/). Docs: bin/letsdo header Usage gains both --init forms; README already documented --init (Features/Getting started/CLI reference/How it works); CHANGELOG 'Added' entry. Evidence: rake test 195 runs / 667 assertions / 0 failures; rubocop lib bin test 48 files / no offenses; manual smoke test of every --init path and exit code.
<!-- SECTION:FINAL_SUMMARY:END -->
