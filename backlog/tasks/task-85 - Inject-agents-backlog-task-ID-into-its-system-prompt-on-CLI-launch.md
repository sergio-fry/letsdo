---
id: TASK-85
title: >-
  Inject agent's own identity (backlog assignee name) into its system prompt on
  CLI launch
status: To Do
assignee: []
created_date: '2026-09-10 07:24'
updated_date: '2026-09-10 07:27'
labels: []
dependencies: []
priority: high
type: enhancement
ordinal: 74000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
When an agent (developer) is launched via CLI, the agent's own identity — the exact name/ID passed in the command line — must be injected into its system prompt automatically, even when the prompt template does not explicitly reference it.\n\nThis identity corresponds to the agent's name in the task tracker / backlog (the assignee name). Currently, creating a new agent gives it a default prompt with no awareness of who it is. Since the CLI invocation already knows the agent's name (e.g. '--agent sergey'), we must pass it through so the agent always knows its own identity.\n\nThis is a foundational improvement: every agent needs to know who it is to correctly self-identify, be assigned tasks, and operate within the backlog system.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Agent's own identity name (from CLI invocation, e.g. '--agent sergey') is injected into its system prompt on every launch
- [ ] #2 Injection succeeds even when the prompt template has no explicit reference to the agent identity (default prompt scenario)
- [ ] #3 The identity is always merged in by the launcher, regardless of prompt template content
- [ ] #4 Backward compatible: existing agents with custom prompts are not broken
- [ ] #5 The injected identity matches the assignee name used in Backlog tasks, enabling task assignment by agent name
<!-- AC:END -->
