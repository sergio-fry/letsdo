---
id: TASK-72
title: 'Gemspec: ship repo docs (docs/**/*.md) in the packaged gem'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:20'
labels: []
dependencies: []
documentation:
  - docs/usage.md
  - docs/prompts.md
  - docs/config.md
type: enhancement
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-65 added user-facing guides in repo docs/ (docs/usage.md, docs/prompts.md, docs/config.md), linked from the README (Guides section). The current spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"], so a gem-installed letsdo gets the README (rendered by rubygems.org) but none of the three guides. Add "docs/**/*.md" to spec.files so the guides ship inside the gem. Coordination: TASK-47 (To Do, @developer) reviews spec.files under AC#5 — if it lands first, fold this glob into that task instead of editing the same line twice; either way the gem must contain the three docs files. Affected letsdo components: letsdo.gemspec (packaging glob), docs/* (artifacts), no runtime code.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 After the change, `gem build letsdo.gemspec` lists docs/usage.md, docs/prompts.md and docs/config.md among the packed files
- [ ] #2 `gem build letsdo.gemspec` succeeds with no warnings
- [ ] #3 `rake test` stays green (0 failures); no new runtime behavior
- [ ] #4 README relative links (docs/usage.md, docs/prompts.md, docs/config.md) resolve for both GitHub rendering and the installed gem
<!-- AC:END -->
