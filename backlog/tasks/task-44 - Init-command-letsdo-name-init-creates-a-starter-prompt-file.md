---
id: TASK-44
title: 'Init command: letsdo <name> --init creates a starter prompt file'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-03 21:13'
labels: []
dependencies:
  - TASK-43
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
- [ ] #1 'letsdo <name> --init' creates agents/<name>.md (mkdir_p) containing exactly Letsdo::DefaultPrompt::TEXT, prints 'created <path>', exits 0 and never starts the agent (no pi spawned in tests)
- [ ] #2 'letsdo --init <name>' behaves identically to the name-first form
- [ ] #3 Existing agents/<name>.md is never overwritten: message to stderr, exit 1, file content unchanged
- [ ] #4 Unsafe names (containing '/', containing '\', '.' or '..') are refused with an error, exit 1; nothing is written outside agents/
- [ ] #5 'letsdo --init' without a name prints usage and exits 1; --version/--help keep their priority when argv[0]; unknown options still exit 1
- [ ] #6 rake test green (0 failures); rubocop on lib/, bin/, test/ — 0 offenses; README and bin/letsdo header document --init; all texts in English (TASK-35)
<!-- AC:END -->
