---
id: TASK-65
title: 'Docs: usage guide + prompt-authoring guide (README expansion vs separate docs)'
status: To Do
assignee:
  - '@analyst'
created_date: '2026-09-04 08:01'
labels: []
dependencies: []
type: docs
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Analyze and produce product documentation beyond the polished README (TASK-46, done): per user request — 'how to use the product', and a guide on writing agent prompts (what to write, good practices, anti-patterns), plus better configuration documentation (env vars, LETSDO_ROOT structure, which prompts live where).

Tasks for the analyst: (1) decide structure — expand README sections vs separate docs/ files (e.g. docs/usage.md, docs/prompts.md, docs/config.md) linked from README, considering RubyGems packaging (spec.files includes docs if added, see TASK-47) and open-source readability; (2) usage guide content: install, first run, agents, loop model (one run = one task, waiting, stop), TUI keys once TASK-42 lands, --init/default prompt once 43/44 land; (3) prompt-authoring guide: what a good agent prompt contains (exactly one task per run, task selection rules, backlog protocol references like in agents/developer.md), what to avoid (multi-task runs, invented work, missing stop conditions), examples incl. existing developer.md/analyst.md; (4) configuration reference: all LETSDO_*/AGENT_* env vars, defaults, examples. Proposals land as new dev tasks (@developer) or analyst-written docs, with review. No code changes in this spike; docs text is the deliverable.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Structure decision recorded: README expansion vs docs/* files (or both) with rationale (gem packaging, discoverability, linkability)
- [ ] #2 Usage guide outline finalized and drafted: covers TUI keys (align TASK-42), --init/default prompt (align TASK-43/44), loop semantics, listening/waiting model
- [ ] #3 Prompt-authoring guide drafted: must-haves / anti-patterns / worked examples from agents/developer.md and agents/analyst.md
- [ ] #4 Config reference complete: every LETSDO_* and AGENT_* variable, default, meaning, example; cross-checked against lib/letsdo/cli.rb
- [ ] #5 Deliverable reviewed and placed in the repo (or a developer task for placement created); English only (TASK-35/48)
<!-- AC:END -->
