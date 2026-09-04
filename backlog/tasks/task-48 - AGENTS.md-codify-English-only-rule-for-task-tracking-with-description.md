---
id: TASK-48
title: 'AGENTS.md: codify English-only rule for task tracking (with description)'
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 07:07'
updated_date: '2026-09-04 07:19'
labels: []
dependencies: []
type: docs
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add a project rule to AGENTS.md: task tracking in this project is done in English. Per user request, the rule must be codified with a proper description (why + scope), not just a one-liner.

Scope of the rule: all tracked artifacts — task titles, descriptions, acceptance criteria, notes/comments, drafts, milestones, decisions, and backlog docs — are written in English (consistent with the existing project convention TASK-35, and open-source friendly). User conversations may stay in Russian; only tracked artifacts are English.

Placement: AGENTS.md currently holds only the Backlog.md Workflow block wrapped in <!-- BACKLOG.MD GUIDELINES START/END --> comments (version-managed by backlog.md-instructions). Add a separate section (e.g. '## Conventions' or '## English Only') AFTER the closing <!-- BACKLOG.MD GUIDELINES END --> marker — do NOT touch the wrapped block. Optional: also pin the canonical one-line project description ('A local agent worker for Backlog.md/markdown tasks') in the same section so README/gemspec/rules reference one consistent definition. The section itself is written in English.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 AGENTS.md has a Conventions/English-Only section stating task tracking artifacts are written in English (titles, descriptions, acceptance criteria, comments, drafts, milestones, decisions, docs)
- [x] #2 Section placed after the BACKLOG.MD GUIDELINES END marker; the version-managed Backlog.md Workflow block is untouched
- [x] #3 The rule is described, not just stated: brief rationale (consistency, open-source readiness, matches TASK-35 convention) included in the section
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Study current AGENTS.md (Backlog.md Workflow block only, ends with <!-- BACKLOG.MD GUIDELINES END -->), TASK-35 convention, and the canonical project description used in README/gemspec.
2. Append a '## Conventions' section AFTER the closing marker: English-only rule for task tracking (scope: titles, descriptions, ACs, notes/comments, drafts, milestones, decisions, docs; rationale: consistency with TASK-35, open-source readiness; user conversations exempt; historical Russian backlog left as-is).
3. Pin the canonical one-line project description ('A local agent worker for Backlog.md/markdown tasks') in the same section.
4. Verify: section exists after the END marker, wrapped Backlog.md block byte-identical, zero Cyrillic in AGENTS.md, no backlog CLI files touched; finalize and commit.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: 'git diff AGENTS.md' shows only 19 added lines, all after the '<!-- BACKLOG.MD GUIDELINES END -->' marker — the version-managed Backlog.md Workflow block is byte-identical to HEAD. Cyrillic scan of AGENTS.md: 0 matches. rake test: 83 runs, 0 failures, 0 errors (unchanged by this docs-only change). Canonical project description pinned in the section: 'A local agent worker for Backlog.md/markdown tasks' (matches letsdo.gemspec summary and README).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added a '## Conventions' section to AGENTS.md after the BACKLOG.MD GUIDELINES END marker, codifying the English-only rule for task tracking: all tracked artifacts (titles, descriptions, acceptance criteria, notes/comments, drafts, milestones, decisions, docs) are written in English, with rationale (TASK-35 consistency, open-source readiness) and the exception (user conversations may stay in any language; existing Russian backlog history left as-is). Also pinned the canonical project description ('A local agent worker for Backlog.md/markdown tasks') as single source of truth. Verified: git diff shows only additions after the END marker (wrapped block untouched), zero Cyrillic in AGENTS.md, rake test 83/0 failures; no backlog CLI files were edited directly.
<!-- SECTION:FINAL_SUMMARY:END -->
