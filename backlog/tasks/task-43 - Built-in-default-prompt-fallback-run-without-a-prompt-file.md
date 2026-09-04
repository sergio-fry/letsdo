---
id: TASK-43
title: Built-in default prompt + fallback run without a prompt file
status: Done
assignee:
  - '@developer'
created_date: '2026-09-03 21:13'
updated_date: '2026-09-04 13:11'
labels: []
dependencies: []
priority: medium
type: enhancement
ordinal: 32000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the fallback to the built-in default prompt (analysis: TASK-41 — read its comments "SCENARIO ANALYSIS", "DESIGN DECISIONS", "BUILT-IN DEFAULT PROMPT" first).

Currently letsdo <name> requires agents/<name>.md and fails with "Unknown agent: <name>" (exit 1) otherwise (Letsdo::PromptStore#read raises UnknownAgentError, Letsdo::CLI#run_agent rescues it before the loop). User requirement: an agent must start even without a prompt file — as an independent worker it runs on the built-in default prompt; the file is an optimization (custom instructions), not a precondition.

What to implement:
1. NEW lib/letsdo/default_prompt.rb: module Letsdo::DefaultPrompt with a frozen TEXT constant containing the canonical default prompt text — take it from TASK-41 comment #3, the block between <---8<--- markers (process-only: one task per run, task-work protocol; no role/project/language specifics). Add the require to lib/letsdo.rb and update its structure comment.
2. Letsdo::PromptStore (lib/letsdo/prompt_store.rb): #read(name) returns nil when agents/<name>.md is missing (remove the raise, remove the @raise doc); add #agent_path(name) -> absolute path of agents/<name>.md (needed by the notification). #create_agent stays out of scope (TASK-44).
3. Letsdo::Agent#run (lib/letsdo/agent.rb): prompt = PromptStore#read(name) || DefaultPrompt::TEXT — a run always has a prompt; update the class docs (no more UnknownAgentError).
4. Letsdo::CLI#run_agent (lib/letsdo/cli.rb): remove the rescue UnknownAgentError branch; when PromptStore#read(name) is nil, print the notification ONCE to stderr before the first loop message and proceed (Agent falls back itself). Exact notification strings (English):
   letsdo: no prompt for <name> at <root>/agents/<name>.md
   letsdo: using the built-in default prompt (create a prompt file with 'letsdo <name> --init')
   where <root> is the resolved LETSDO_ROOT (default pwd). This is the only path probed — state it literally. Do not repeat the message on later loop iterations. The loop (Letsdo::Loop/AgentLoop from TASK-39) must NOT change.
5. Letsdo::Errors (lib/letsdo/errors.rb): remove UnknownAgentError (with the fallback there are no unknown agents); keep the base Letsdo::Error.
6. Tests: test/prompt_store_test.rb (read -> nil for missing agent incl. no agents/ dir, agent_path; remove the UnknownAgentError tests), test/agent_test.rb (running an unknown name launches fake pi with ARGV.last == Letsdo::DefaultPrompt::TEXT), test/cli_test.rb (replace test_unknown_agent_fails_before_the_loop with: missing-prompt run proceeds into the loop, both notification lines present exactly once on stderr, existing prompt -> no notification). Remove errors tests referencing UnknownAgentError.
7. bin/letsdo header comment and README.md: document that an agent without a prompt file runs with the built-in default prompt + one-time announcement; README code-structure section gains Letsdo::DefaultPrompt.

Requirement origin: TASK-41 (analyst spike). Constraints — TASK-35 (all texts English), TASK-37 (rubocop 0 offenses), TASK-39 (orchestrator loop shape untouched: one run = one task, waiting, signals), TASK-40 independent (streamer output changes do not affect prompts).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 letsdo <name> with no agents/<name>.md starts the agent using the built-in default prompt: the fake pi receives Letsdo::DefaultPrompt::TEXT as the prompt; the orchestrator loop behavior is unchanged (N open tasks -> N runs, wait when none, clean stop) — TASK-39 shape intact
- [x] #2 One-time notification on stderr, before the first loop message, listing exactly the checked path <root>/agents/<name>.md and the hint 'letsdo <name> --init'; exactly once per process; a run with an existing prompt file prints no notification
- [x] #3 Letsdo::PromptStore#read returns nil for a missing agent (no raise) and #agent_path returns the absolute path of agents/<name>.md; existing prompt-store tests updated
- [x] #4 Letsdo::DefaultPrompt::TEXT exists in lib/letsdo/default_prompt.rb and equals the canonical <---8<--- block from TASK-41 comment #3; lib/letsdo.rb requires it
- [x] #5 Letsdo::Errors: UnknownAgentError removed together with its tests; Letsdo::Error kept; no UnknownAgentError references remain in lib/ or test/
- [x] #6 rake test green (0 failures); rubocop on lib/, bin/, test/ — 0 offenses (TASK-37); README documents the fallback; all texts in English (TASK-35)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. NEW lib/letsdo/default_prompt.rb: Letsdo::DefaultPrompt::TEXT (frozen) = canonical text from TASK-41 comment #3 (between the 8< markers); require it in lib/letsdo.rb and update the structure comment.
2. PromptStore: #read(name) -> nil when agents/<name>.md missing (drop raise + @raise doc); add #agent_path(name) -> absolute path. #create_agent stays out of scope (TASK-44).
3. Agent#run: prompt = PromptStore#read(name) || DefaultPrompt::TEXT; drop UnknownAgentError from docs.
4. CLI#run_agent: remove the rescue UnknownAgentError branch; when read(name) is nil print both notification lines once to stderr before the loop starts (exact strings from TASK-41 #2); loop (AgentLoop) untouched.
5. errors.rb: remove UnknownAgentError, keep Letsdo::Error.
6. Tests: prompt_store_test (read -> nil incl. no agents/, agent_path absolute; drop 3 UnknownAgentError tests), agent_test (unknown name -> fake pi argv last == DefaultPrompt::TEXT; drop 2 raise tests), cli_test (replace unknown-agent tests: missing-prompt run proceeds into loop, both notification lines exactly once on stderr before first loop message, existing prompt -> no notification).
7. Docs: bin/letsdo header (fallback + one-time announcement), README code-structure already has DefaultPrompt (verify suffices), docs/usage.md exit-code table drops 'unknown agent name', CHANGELOG Added entry.
8. Verify: rake test 0 failures, rubocop --no-server lib bin test 0 offenses, commit incl. backlog folder.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: rake test = 181 runs, 579 assertions, 0 failures, 0 errors, 0 skips. rubocop --no-server lib bin test = 47 files, no offenses. Manual smoke run: 'letsdo newcomer' with no agents/newcomer.md printed the two notification lines once (exact path /tmp/.../agents/newcomer.md + 'letsdo newcomer --init' hint), then the loop waited and retried as before; notification not repeated. AC4: verified programmatically that DefaultPrompt::TEXT content matches the canonical 8< block in TASK-41 comment #3 (whitespace-normalized equality; padding blank lines around the fenced block excluded; TEXT frozen, starts with '# Task agent', ends with '- Do not complete several tasks in one run.'). docs/usage.md exit-code table no longer lists 'unknown agent name' (no unknown agents anymore); CHANGELOG.md gains an 'Added' entry.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
--help
<!-- SECTION:FINAL_SUMMARY:END -->
