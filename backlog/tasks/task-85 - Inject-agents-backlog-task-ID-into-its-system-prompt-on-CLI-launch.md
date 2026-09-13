---
id: TASK-85
title: >-
  Inject agent's own identity (backlog assignee name) into its system prompt on
  CLI launch
status: Done
assignee:
  - '@developer'
created_date: '2026-09-10 07:24'
updated_date: '2026-09-13 13:53'
labels: []
dependencies: []
priority: high
type: enhancement
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When an agent is launched via the CLI (`letsdo <name>`), the agent's own identity must be injected into its system prompt automatically, even when the prompt template does not reference it.

The identity is the agent name plus its backlog assignee handle (default `@<name>`, overridable via `AGENT_ASSIGNEE_HANDLE`). Today a fresh agent gets a prompt with no awareness of who it is; the launcher already knows the name and handle, so it must pass them through so every agent always knows its own identity — to self-identify and to work the tasks assigned to it.

Note: the CLI invocation is `letsdo <name>` (there is no `--agent` flag). The injected identity must match the assignee handle used for backlog task assignment (Config#assignee_handle, default `@<name>`).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 An agent launched with `letsdo <name>` gets its name and assignee handle (default `@<name>`) injected into its system prompt on every launch
- [x] #2 Injection works when the prompt template has no identity reference (the built-in default prompt scenario)
- [x] #3 The identity is merged in by the launcher regardless of prompt template content
- [x] #4 Backward compatible: existing agents with custom prompts are not broken
- [x] #5 The injected handle matches the assignee handle used for backlog task assignment (Config#assignee_handle, default `@<name>`)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add Letsdo::AgentIdentity (lib/letsdo/agent_identity.rb): build the identity preamble from name + handle and inject it at the head of any prompt (pure, testable).
2. Letsdo::Agent gains an optional handle: keyword (default @<name>) and prepends the identity preamble in #run to whatever prompt it uses (file prompt or built-in default), so injection happens on every run regardless of template content.
3. CLI::Builder#agent_for passes handle: assignee_handle(name) (Config#assignee_handle) so both plain and TUI launches inject the same handle used for backlog assignment; an AGENT_ASSIGNEE_HANDLE override flows through.
4. Require the new file from lib/letsdo.rb; keep Agent's backend_factory contract unchanged.
5. Tests: new test/agent_identity_test.rb; adjust test/agent_test.rb and test/cli_test.rb expectations that assumed the raw prompt is passed verbatim; add a CLI test proving the env-overridden handle reaches the prompt.
6. Docs: docs/prompts.md (identity is injected automatically; custom prompts stay valid) and CHANGELOG.md Unreleased.
7. Verify: rake test green.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation: new Letsdo::AgentIdentity (lib/letsdo/agent_identity.rb) builds a short identity block from name + handle and prepends it to any prompt. Letsdo::Agent gained an optional handle: keyword (default @<name>) and injects the identity in #run, right after the prompt is read (file prompt or built-in default) and before the backend factory call. CLI::Builder#agent_for passes handle: assignee_handle(name) (Config#assignee_handle), so plain and TUI launches inject the same handle the loop uses for backlog assignment; AGENT_ASSIGNEE_HANDLE overrides flow through. Identity was always injected regardless of template content (additive, so custom prompts keep working unchanged); --init still writes the raw DefaultPrompt::TEXT.

Validation: rake test -> 334 runs, 967 assertions, 0 failures, 0 errors. rubocop --no-server lib bin test -> 69 files, no offenses. Manual end-to-end: LETSDO_ROOT=<tmp> AGENT_ASSIGNEE_HANDLE=@someone ruby -Ilib bin/letsdo developer against test/fixtures/fake_pi recorded the prompt starting with '# Your identity ... You are the agent `developer`. Your backlog assignee handle is `@someone`' followed by the custom template. New tests: test/agent_identity_test.rb (module + agent-level injection, default-prompt case, launcher handle), test/cli_test.rb CliIdentityTest (default handle reaches the prompt; env override reaches the prompt and not the default), updated prompt-verbatim assertions in AgentTest/CliRunTest.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Agent identity is now injected by the launcher on every run: Letsdo::AgentIdentity builds a name + backlog assignee handle block that Letsdo::Agent prepends to whatever prompt it loaded (agents/<name>.md or the built-in default), and CLI::Builder#agent_for passes the Config#assignee_handle value so the injected handle always matches the backlog assignment. Verified with rake test (334 runs, 0 failures), rubocop (no offenses), a manual end-to-end letsdo launch showing the identity block with an AGENT_ASSIGNEE_HANDLE override, and new module/agent/CLI tests covering the default and custom-prompt paths.
<!-- SECTION:FINAL_SUMMARY:END -->
