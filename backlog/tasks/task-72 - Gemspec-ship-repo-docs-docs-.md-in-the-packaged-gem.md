---
id: TASK-72
title: 'Gemspec: ship repo docs (docs/**/*.md) in the packaged gem'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 08:20'
updated_date: '2026-09-13 14:05'
labels: []
dependencies: []
documentation:
  - docs/usage.md
  - docs/prompts.md
  - docs/config.md
priority: medium
type: enhancement
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-65 added user-facing guides in repo docs/ (docs/usage.md, docs/prompts.md, docs/config.md), linked from the README (Guides section). The current spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"], so a gem-installed letsdo gets the README (rendered by rubygems.org) but none of the three guides. Add "docs/**/*.md" to spec.files so the guides ship inside the gem. Coordination: TASK-47 (To Do, @developer) reviews spec.files under AC#5 — if it lands first, fold this glob into that task instead of editing the same line twice; either way the gem must contain the three docs files. Affected letsdo components: letsdo.gemspec (packaging glob), docs/* (artifacts), no runtime code.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 After the change, `gem build letsdo.gemspec` lists docs/usage.md, docs/prompts.md and docs/config.md among the packed files
- [x] #2 `gem build letsdo.gemspec` succeeds with no warnings
- [x] #3 `rake test` stays green (0 failures); no new runtime behavior
- [x] #4 README relative links (docs/usage.md, docs/prompts.md, docs/config.md) resolve for both GitHub rendering and the installed gem
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add the docs glob (docs/**/*.md) to spec.files in letsdo.gemspec, next to the other packaged artifacts. TASK-47 is already Done, so no coordination conflict remains.
2. Verify AC#1: gem build letsdo.gemspec and inspect the packed file list (tar of the .gem / gem contents) — docs/usage.md, docs/prompts.md, docs/config.md must be present.
3. Verify AC#2: gem build emits no warnings.
4. Verify AC#3: rake test stays green.
5. Verify AC#4: confirm the three docs files exist in the gem so README relative links resolve both on GitHub (files in repo) and for an installed gem (files in gemdir).
6. Remove the built .gem artifact; finalize and commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
TASK-47 (gemspec review) was already Done, so no coordination conflict: the docs glob was folded into the existing spec.files line.

Verification evidence:
- AC#1: gem build letsdo.gemspec -> letsdo-0.4.0.gem; unpacked data.tar.gz file list contains docs/config.md, docs/prompts.md, docs/usage.md (plus bin/letsdo, CHANGELOG.md, LICENSE, README.md, letsdo.gemspec, lib/**).
- AC#2: gem build printed only 'Successfully built RubyGem' with no warnings.
- AC#3: rake test -> 368 runs, 1088 assertions, 0 failures, 0 errors, 0 skips. No runtime code touched.
- AC#4: README links docs/usage.md, docs/prompts.md, docs/config.md are relative and now the three files exist at the same relative path inside the gem (and in the repo), so they resolve for both GitHub rendering and an installed gem.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added 'docs/**/*.md' to spec.files in letsdo.gemspec so the three user-facing guides (docs/usage.md, docs/prompts.md, docs/config.md) ship inside the gem. No runtime code changes. Verified: unpacked gem contains all three docs; gem build succeeds with no warnings; rake test green (368 runs, 0 failures); README relative links now resolve both on GitHub and for an installed gem.
<!-- SECTION:FINAL_SUMMARY:END -->
