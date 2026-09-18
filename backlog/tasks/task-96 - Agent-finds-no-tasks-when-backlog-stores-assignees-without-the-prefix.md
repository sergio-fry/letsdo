---
id: TASK-96
title: >-
  letsdo must use bare assignee names (developer) in the tracker - '@' is
  prompt-only notation
status: Done
assignee:
  - developer
created_date: '2026-09-18 08:07'
updated_date: '2026-09-18 10:30'
labels: []
dependencies: []
references:
  - /root/projects/sigma-dev
priority: high
type: bug
ordinal: 85000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Reported from /root/projects/sigma-dev: three open tasks (SIG-5..SIG-7) are assigned to developer, but letsdo developer idles and polls every ~10 s reporting 0 tasks. backlog.md 1.50.1 matches the --assignee filter by exact string: letsdo queries "--assignee @developer" (Config#assignee_handle defaults to "@<name>") while sigma-dev tasks store "assignee: developer". Verified: "--assignee @developer" returns 0 tasks, "--assignee developer" returns all 3; --ready and --sort filters behave correctly.

Correction from the project lead (2026-09-18): the @ prefix is NOT part of the assignee identity and must never be stored in the tracker. @ is only a notation in prompts and prose marking an exact identifier: "@developer" in text means the assignee "developer". The canonical tracker value is the bare name (developer, analyst, human). So the bug is the opposite of the original framing: not that sigma-dev data lacks @, but that letsdo defaults to an @-prefixed handle and its own convention, templates, docs and backlog data wrongly bake @ into the tracker. sigma-dev itself needs no data change: once letsdo filters by the bare name, its tasks are found as-is.

Fix scope:
1. Config#assignee_handle defaults to the bare agent name; Providers::Backlog queries "--assignee developer".
2. The identity block (TASK-85), TUI header and docs may keep @name as display notation, but the tracker value they present must be the bare name.
3. letsdo own conventions aligned: AGENTS.md assignee rules (-a developer), agents/developer.md and agents/analyst.md command examples (--assignee developer, -a developer, --comment-author), README, docs/config.md, docs/usage.md, docs/prompts.md, docs/task-selection.md.
4. letsdo own backlog data migrated: tasks stored with "@human"/"@developer" assignees are reassigned to bare names via the backlog CLI (no manual front-matter edits).
5. AGENT_ASSIGNEE_HANDLE remains as an escape hatch for legacy setups; a legacy @-prefixed configured handle or stored assignees must surface a visible warning (doctor check) instead of silently matching nothing.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 letsdo developer picks up open tasks whose assignee is stored as bare "developer" by default, with no AGENT_ASSIGNEE_HANDLE override
- [x] #2 The identity block, TUI header and docs present the tracker assignee as the bare name; @ appears only as prose notation
- [x] #3 No letsdo artifact (AGENTS.md, agents/*.md, README, docs) instructs storing an @-prefixed assignee in the tracker; all backlog command examples use bare names
- [x] #4 Existing letsdo backlog tasks with @-prefixed assignees are reassigned to bare names via the backlog CLI
- [x] #5 Doctor warns when the configured handle or stored assignees are @-prefixed (legacy data), and AGENT_ASSIGNEE_HANDLE still overrides the default for legacy setups
- [x] #6 Unit tests cover the bare-name default and the provider query line; rake test and RuboCop stay green
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Config#assignee_handle defaults to the bare agent name; expose the raw AGENT_ASSIGNEE_HANDLE override for doctor (legacy escape hatch stays verbatim). 2. Providers::Backlog: drop --assignee from the CLI query, match the handle in Ruby after normalization (leading @, whitespace, case); expose assignee_variants (legacy @-prefixed stored values). 3. AgentLoop: once-per-run stderr warning when the batch matched only after normalization; BuilderAssembly passes the provider object. 4. Doctor assignee_check (bare-canonical): WARN on an @-prefixed AGENT_ASSIGNEE_HANDLE override or @-prefixed stored assignees (legacy), INFO when the backlog is unreadable, OK otherwise. 5. Identity block + TUI header: present the tracker assignee bare; @ stays prose/display notation only. 6. fake_backlog 'assignees' scenario + tests: config bare default, provider argv/matching/variants/nil-handle, loop warning, doctor OK/WARN/INFO. 7. Docs flip to bare names: AGENTS.md, agents/*.md, README, docs/config.md, usage.md, prompts.md, task-selection.md, CHANGELOG. 8. Migrate letsdo backlog data: TASK-96 assignee @developer -> developer via CLI. 9. Verify: rake test, rubocop, manual provider run against this repo's real backlog.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Docs flip complete (step 7): AGENTS.md team rules rewritten around bare names + new bare-canonical rule; agents/developer.md and agents/analyst.md command examples now --assignee developer / -a developer / --comment-author analyst; README (features, env table, provider description, niche paragraph); docs/config.md (default, env table, resolution order), docs/usage.md (provider line, loop query, TUI header note, multi-agent section), docs/prompts.md (identity injection, checklist), docs/task-selection.md (provider step explains Ruby-side matching and why the CLI line carries no --assignee). CHANGELOG: new [Unreleased] Fixed/Changed section. RuboCop: extracted AgentLoopAssigneeHints concern (lib/letsdo/agent_loop/assignee_hints.rb) to keep AgentLoopTasks under the module-length limit; folded report_backoff into report_provider. Manual verification against the real repo backlog: provider resolves handle 'developer', returns TASK-96 (stored bare), assignee_variants == []. Doctor live run flagged open TASK-76 stored as '@human' (WARN) -> migrated via 'backlog task edit TASK-76 -a human' -> doctor now [ OK ] assignee names are stored bare (canonical). Open-task sweep: no open task carries an @-prefixed assignee; Done/archived history (e.g. TASK-40, archive TASK-57/61) intentionally left as-is per the leave-history-as-is convention, and the doctor check deliberately scopes to open tasks (the only ones the loop reads). rake test: 421 runs, 1227 assertions, 0 failures, 0 errors. RuboCop: 84 files, 0 offenses.

Release-pass validation (2026-09-18): reproduced the doctor legacy WARN on an @-prefixed stored assignee, migrated TASK-96 back to bare via CLI, doctor OK; live provider batch with handle developer returns [TASK-96], assignee_variants empty; rake test 421 runs / 1223 assertions / 0 failures; RuboCop 84 files, 0 offenses. Done/archived tasks keep legacy @ assignees by design (documented in the fix commit).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Providers::Backlog no longer passes --assignee to the backlog CLI (exact-string match) and filters the normalized batch in Ruby, tolerating legacy @-prefix/whitespace/case variants; Config#assignee_handle defaults to the bare agent name with AGENT_ASSIGNEE_HANDLE as a verbatim escape hatch; AgentLoop prints a once-per-run stderr hint on normalization-only matches; doctor WARNs on legacy @-prefixed override or stored assignees; the identity block presents the bare name while the TUI keeps @name as display-only notation; docs and templates flipped (AGENTS.md, agents/*.md, README, docs/*); open backlog tasks migrated via the CLI (Done/archived history left as-is). Verified live: provider run with handle developer finds bare-stored TASK-96 with empty variants; doctor WARN-to-OK across a real legacy reassignment; rake test 421 runs / 0 failures; RuboCop 84 files / 0 offenses.
<!-- SECTION:FINAL_SUMMARY:END -->
