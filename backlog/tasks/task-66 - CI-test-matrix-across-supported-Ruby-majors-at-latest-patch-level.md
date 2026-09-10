---
id: TASK-66
title: 'CI: test matrix across supported Ruby majors at latest patch level'
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 08:01'
updated_date: '2026-09-10 20:12'
labels: []
dependencies:
  - TASK-47
priority: medium
type: chore
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Extend .github/workflows/ci.yml to test all currently-supported Ruby major versions at their latest patch level (per user request: 'a few current versions — all supported majors at latest patch'; user explicitly wants 3.x and 4.x covered, e.g. the newest patch of each supported major).

Facts (checked 2026-09-04 via endoflife.date/api/ruby.json): supported majors today — 3.3 (latest 3.3.12, EOL 2027-03), 3.4 (latest 3.4.10, EOL 2028-03), 4.0 (latest 4.0.6, EOL 2029-03). 3.2 (3.2.11) is EOL since 2026-03 — exclude. Verify at execution time (ruby-lang.org/en/downloads/branches + endoflife.date): if 3.5 exists as a supported branch (planned Dec 2025 release), include its latest patch too. Current matrix is ruby: ['3.3'] with a stale comment 'Explicit Ruby 3.x — satisfies letsdo.gemspec required_ruby_version >= 3.0'.

Design: ruby/setup-ruby resolves latest patch per minor — matrix over majors ['3.3','3.4',(3.5?),'4.0'] is enough; jobs run gem build + rake test (existing steps unchanged). required_ruby_version alignment is TASK-47's decision — coordinate so the matrix matches the floor (if 47 narrows the floor, drop older majors from the matrix; if it widens, the matrix is the evidence). Also add one 'latest/head' job only if stable on all supported majors (decide and document). CI must stay green; failing majors are signal to bump the required floor, not to disable the job.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 CI matrix covers every currently-supported Ruby major at latest patch: 3.3, 3.4, 4.0 at minimum (3.2 EOL excluded); 3.5 included if confirmed as supported at execution time
- [x] #2 gem build + rake test pass on every matrix entry — no job disabled or masked; consistent with the required_ruby_version chosen in TASK-47
- [x] #3 Stale CI comment ('Explicit Ruby 3.x...') removed/replaced with the current matrix rationale
- [x] #4 Decision on a head/latest job recorded in the task (included only if stable; justification noted)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify supported Ruby majors at execution time via endoflife.date and ruby-lang.org (done: 3.3, 3.4, 4.0; 3.5 preview only; 3.2 EOL).
2. Emulate CI install path: for each version (3.3, 3.4, 4.0), build gem, install it (which pulls runtime deps), then run rake test.
3. If all three versions pass, update .github/workflows/ci.yml matrix to ruby: ['3.3', '3.4', '4.0'].
4. Update the stale CI comment with current matrix rationale.
5. Decide on head/latest job and record decision in the task (acceptance #4).
6. Verify CI will stay green on all matrix entries.
7. Finalize and commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Decision on head/latest job: NO HEAD job added. The matrix already covers every supported major at its latest patch (3.3, 3.4, 4.0). Ruby 3.5 was preview-only at execution time (2026-09-10) — it joins when it ships stable. HEAD jobs (ruby-head) would test unstable pre-release builds (3.5-preview, 4.1-dev) and add noise without covering a supported branch. If CI needs wider coverage, add 3.5 to the matrix once it becomes a stable supported release.

Verification (exact CI path: gem build + gem install ./letsdo-*.gem + letsdo --version + rake test): Ruby 3.3.12 - 267 runs / 747 assertions, 0 failures; Ruby 3.4.10 - 267 runs / 736 assertions, 0 failures; Ruby 4.0.2 - 267 runs / 786 assertions, 0 failures. Matrix YAML re-parsed: ['3.3', '3.4', '4.0']. Supported majors verified 2026-09-10 via endoflife.date/ruby.json + ruby-lang.org/en/downloads/branches: 3.3 (latest 3.3.12), 3.4 (latest 3.4.10), 4.0 (latest 4.0.6); 3.2 EOL; 3.5 preview-only (not a stable branch yet) so not added.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extended .github/workflows/ci.yml to test every currently-supported Ruby major at its latest patch. Matrix is now ['3.3','3.4','4.0'] (was ['3.3','4.0']); supported majors confirmed at execution time 2026-09-10 via endoflife.date/ruby.json and ruby-lang.org/en/downloads/branches — 3.3 (3.3.12), 3.4 (3.4.10), 4.0 (4.0.6); 3.2 is EOL (excluded); Ruby 3.5 is preview-only so it stays out until it ships a stable branch. Replaced the stale 'Explicit Ruby 3.x' comment with the current matrix rationale (supported majors at latest patch, EOL exclusion, floor alignment with gemspec required_ruby_version >= 3.3, TASK-80 note retained). Decided NO separate head/latest job: the matrix already covers every supported major at latest patch; ruby-head would test unstable pre-release builds — decision recorded in notes. Verified with the exact CI path (gem build + gem install + letsdo --version + rake test) per matrix entry: 3.3.12 = 267 runs/747 assertions 0 failures, 3.4.10 = 267 runs/736 assertions 0 failures, 4.0.2 = 267 runs/786 assertions 0 failures; workflow YAML re-parsed cleanly.
<!-- SECTION:FINAL_SUMMARY:END -->
