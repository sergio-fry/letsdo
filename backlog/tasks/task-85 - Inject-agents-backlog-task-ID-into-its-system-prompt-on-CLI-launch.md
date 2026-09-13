---
id: TASK-85
title: >-
  Inject agent's own identity (backlog assignee name) into its system prompt on
  CLI launch
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-10 07:24'
updated_date: '2026-09-13 13:28'
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
- [ ] #1 An agent launched with `letsdo <name>` gets its name and assignee handle (default `@<name>`) injected into its system prompt on every launch
- [ ] #2 Injection works when the prompt template has no identity reference (the built-in default prompt scenario)
- [ ] #3 The identity is merged in by the launcher regardless of prompt template content
- [ ] #4 Backward compatible: existing agents with custom prompts are not broken
- [ ] #5 The injected handle matches the assignee handle used for backlog task assignment (Config#assignee_handle, default `@<name>`)
<!-- AC:END -->
