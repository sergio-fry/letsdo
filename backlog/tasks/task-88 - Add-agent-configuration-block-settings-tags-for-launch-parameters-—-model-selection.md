---
id: TASK-88
title: >-
  Add agent configuration block (settings/tags) for launch parameters — model
  selection
status: Done
assignee:
  - '@developer'
created_date: '2026-09-10 07:34'
updated_date: '2026-09-10 10:25'
labels: []
dependencies: []
priority: high
type: enhancement
ordinal: 77000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a configuration block to the agent description/definition that stores launch settings and tags, similar to how OpenCode does it.\n\nPrimary use case: specify which model a particular agent uses (e.g. gpt-4, claude-3-5-sonnet, etc.). Currently there is no place to define per-agent launch parameters; they are either hardcoded or set globally.\n\nThe config block should be extensible so new parameters can be added later without breaking existing agents.\n\nInspired by OpenCode's approach: the agent definition includes a structured block with settings that the launcher reads before starting the agent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Agent definition includes a structured configuration block for launch settings
- [x] #2 Model selection is configurable per agent (e.g. '--model gpt-4o' or equivalent) and passed to the launcher
- [x] #3 Config block is extensible — adding new parameters does not break existing agent definitions
- [x] #4 Default values work when a parameter is not specified in the config block
- [x] #5 Format/inspiration: similar to how OpenCode structures agent settings (tags, model, etc.)
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added structured YAML front-matter configuration block to agent definitions, parsed by PromptStore#config. Model selection per agent is now passed to the launcher (e.g. model: gpt-4o). Extensible, defaults to no-op, validated via Minitest suite.
<!-- SECTION:FINAL_SUMMARY:END -->
