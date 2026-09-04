---
id: TASK-66
title: 'CI: test matrix across supported Ruby majors at latest patch level'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 08:01'
updated_date: '2026-09-04 10:27'
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
- [ ] #1 CI matrix covers every currently-supported Ruby major at latest patch: 3.3, 3.4, 4.0 at minimum (3.2 EOL excluded); 3.5 included if confirmed as supported at execution time
- [ ] #2 gem build + rake test pass on every matrix entry — no job disabled or masked; consistent with the required_ruby_version chosen in TASK-47
- [ ] #3 Stale CI comment ('Explicit Ruby 3.x...') removed/replaced with the current matrix rationale
- [ ] #4 Decision on a head/latest job recorded in the task (included only if stable; justification noted)
<!-- AC:END -->
