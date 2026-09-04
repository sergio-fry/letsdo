---
id: TASK-37
title: 'RuboCop: default styles, fix the code, verify in CI'
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-03 20:27'
updated_date: '2026-09-04 07:25'
labels: []
dependencies:
  - TASK-36
ordinal: 26000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Enable RuboCop in the letsdo project. No custom styles/rules are added: the default RuboCop configuration is used as-is (as it comes "out of the box"), no .rubocop.yml with disables or custom cops. Needed: (1) add rubocop as a dev dependency; (2) run rubocop with the default config over lib/, bin/, test/; (3) fix violations — autocorrect (rubocop -A) plus the remaining ones manually, reach 0 offenses. At task creation time the default run reports 554 offenses (513 autocorrectable) in 21 files — the number in the task is informational, not a criterion; the target is 0 offenses; (4) the style check becomes a step of the CI build from TASK-36 (the workflow fails on violations). Behavior and logic do not change: code style only.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 rubocop is added as a dev dependency and runs from the project root
- [ ] #2 Configuration is default-only; no custom styles/exclusions in .rubocop.yml
- [ ] #3 rubocop over lib/, bin/, test/ reports 0 offenses
- [ ] #4 rake test stays green (0 failures) after the style edits
- [ ] #5 A rubocop step is added to the CI workflow from TASK-36: the build fails on style violations
<!-- AC:END -->
