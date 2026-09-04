---
id: TASK-65
title: 'Docs: usage guide + prompt-authoring guide (README expansion vs separate docs)'
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 08:01'
updated_date: '2026-09-04 08:22'
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
- [x] #1 Structure decision recorded: README expansion vs docs/* files (or both) with rationale (gem packaging, discoverability, linkability)
- [x] #2 Usage guide outline finalized and drafted: covers TUI keys (align TASK-42), --init/default prompt (align TASK-43/44), loop semantics, listening/waiting model
- [x] #3 Prompt-authoring guide drafted: must-haves / anti-patterns / worked examples from agents/developer.md and agents/analyst.md
- [x] #4 Config reference complete: every LETSDO_* and AGENT_* variable, default, meaning, example; cross-checked against lib/letsdo/cli.rb
- [x] #5 Deliverable reviewed and placed in the repo (or a developer task for placement created); English only (TASK-35/48)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Structure decision: separate docs/ files (docs/usage.md, docs/prompts.md, docs/config.md) linked from README — keeps the TASK-46 landing page readable, makes each guide deep-linkable, and fits gem packaging (spec.files gains docs/**/*.md via a @developer follow-up, TASK-47 coordinates).
2. docs/usage.md: prerequisites, install, first run (--init aligns TASK-43/44), plain-mode session anatomy, loop semantics (one run = one task, waiting/listening, stop), TUI mode (engagement condition, header zones, stream, keys per lib/letsdo/tui/* as implemented in TASK-42, quit/pause/refresh), multi-agent notes.
3. docs/prompts.md: prompt must-haves (identity, one-task-per-run rule, task selection, protocol, prohibitions), anti-patterns, worked examples excerpting agents/developer.md + agents/analyst.md, checklist.
4. docs/config.md: full reference of every env var (LETSDO_ROOT, LETSDO_PI_FLAGS, AGENT_PI_FLAGS, LETSDO_PI_COMMAND, AGENT_ASSIGNEE_HANDLE, LETSDO_WAIT_SECONDS, AGENT_WAIT_SECONDS, LETSDO_BACKLOG_COMMAND, LETSDO_DEBUG) cross-checked against lib/letsdo/cli.rb, agent_loop.rb, pi_runner.rb + project layout + TERM gating.
5. README: link the three guides (Getting started, Config, How it works).
6. Create @developer task: spec.files to include docs/**/*.md (gem build ships the guides); AC: gem build shows docs in the packed file list, rakefake green.
7. Self-review (env vars vs code, TUI keys vs session.rb/input.rb, English, cross-links), finalize TASK-65, commit docs + backlog folder.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Deliverables written: docs/usage.md, docs/prompts.md, docs/config.md (English); README updated with a Guides section (TOC + links in Getting started and Configuration).

Structure decision (AC#1): separate docs/* files linked from README. Rationale: README stays the scannable TASK-46 landing page ('why + quickstart'); the three deep guides become individually linkable from issues/PRs; gem packaging is a one-line spec.files addition (follow-up dev task); matches the English-only docs convention. Option A (expand README) rejected: would push the landing page past ~20 KB and mix reference material with the pitch.

Cross-check vs code (objective, done via grep):
- config.md lists all 9 runtime vars + TERM; each confirmed at its read site: LETSDO_ROOT, LETSDO_PI_FLAGS/AGENT_PI_FLAGS (cli.rb#parse_pi_flags), LETSDO_PI_COMMAND (cli.rb#pi_command, default PiRunner::COMMAND='pi'), AGENT_ASSIGNEE_HANDLE (cli.rb#assignee_handle), LETSDO_WAIT_SECONDS/AGENT_WAIT_SECONDS (cli.rb#wait_seconds, default 10.0), LETSDO_BACKLOG_COMMAND (cli.rb#backlog_command), LETSDO_DEBUG (agent_loop.rb:54 + pi_runner.rb:47, enabled when ="1"), TERM (cli.rb#tui?).
- usage.md TUI keys match the TASK-42 implementation exactly: up/down/page_up/page_down/home/end/p/r/q/ctrl_c from session.rb#handle_key + input.rb KEY_BY_VALUE; SIGWINCH resize, alt-screen teardown, exit-0 quit, tui? gating (stdout tty && stdin tty && TERM != dumb) all documented as implemented.
- Loop service messages quoted verbatim from agent_loop.rb#wrapped_provider/wrapped_run (messages, retry interval, backlog-unavailable pause, non-zero exit reporting).
- --init/default-prompt sections intentionally align with the README (TASK-43/44 designed behavior); noted: validate when TASK-43/44 land.

Validation: docs are markdown-only (docs/*.md + README links) and referenced by no test (grep: only letsdo.gemspec:33 mentions README.md in spec.files). Per-file test run shows the current red suite (14 failures/10 errors of 147 runs) is confined to the developer's uncommitted TASK-42 files: cli_test.rb, output_streamer_test.rb, tui_input/tui_metrics/tui_renderer/tui_session tests; all pre-existing files (agent, backlog_tasks, loop, pi_runner, prompt_store) pass standalone. TASK-65 introduces no code, so it adds no test burden.
Follow-up for @developer created: TASK-72 (gemspec packs docs/**/*.md) — depends on nothing, coordinate with TASK-47.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
TASK-65 done: product docs written as analyst deliverables and placed in the repo. Structure decision (AC#1): separate docs/ guides linked from README instead of expanding it — keeps the TASK-46 landing page scannable and each guide deep-linkable; gem packaging handled via TASK-72. Deliverables: docs/usage.md (install, first run, loop semantics, plain-mode session anatomy, TUI header/state/keys per the implemented TASK-42 code, exit codes), docs/prompts.md (must-haves, anti-patterns, worked examples from agents/developer.md + agents/analyst.md, checklist), docs/config.md (all 9 runtime env vars + TERM with defaults, precedences, examples and read sites), README updated (Guides section in TOC, links from Getting started and Configuration). Verified (AC#2-5): env vars cross-checked against lib/letsdo/cli.rb (lines 156,162,173-174,200-201, root/pi/backlog fetches), agent_loop.rb:54, pi_runner.rb:47; TUI keys matched to session.rb#handle_key + input.rb KEY_BY_VALUE; loop messages quoted verbatim from agent_loop.rb; all links resolve; English only (TASK-35/48). No code changed. Handoff: TASK-72 created for @developer (gemspec to include docs/**/*.md, with gem-build + rake test ACs). Current red test suite is the developer's uncommitted TASK-42 work, unrelated to this docs-only task.
<!-- SECTION:FINAL_SUMMARY:END -->
