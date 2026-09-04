---
id: TASK-49
title: 'Translate open tasks to English (TASK-37, TASK-40, TASK-45)'
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 07:07'
updated_date: '2026-09-04 07:27'
labels: []
dependencies:
  - TASK-48
type: chore
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Translate the currently open backlog tasks that still contain Russian into English, per the English-only task tracking rule (TASK-48). Scan (2026-09-04) shows exactly three open tasks with Cyrillic content: TASK-37 ("RuboCop: default styles, fix the code, verify in CI"), TASK-40 ("Remove tool result output: only tool invocation lines with time"), TASK-45 ("Wake the loop on backlog file changes instead of polling every ~10 s (inotify/FSEvents)"). All other open tasks (42/43/44/46/47) are already English.

Translate what exists in each task: title, description, acceptance criteria, notes/comments. Preserve technical meaning and specifics (task numbers, Ruby/RuboCop terms, inotify/FSEvents). Only 'backlog task edit' via the CLI — never direct edits to backlog/tasks/*.md (project rule: backlog files are CLI-only).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 TASK-37, TASK-40, TASK-45 fully translated to English: titles, descriptions, acceptance criteria, notes
- [x] #2 Verified with a Cyrillic scan of backlog/tasks/*.md: zero open task files contain Cyrillic after the translation
- [x] #3 All edits applied via backlog task edit CLI; no direct markdown file edits
- [x] #4 Translation preserves exact technical meaning (no dropped details like task numbers, tool names, timing)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Move TASK-49 to In Progress; baseline scan confirms exactly three open tasks contain Cyrillic (TASK-37, TASK-40, TASK-45); no notes/comments exist on them (verified), so translation scope = title + description + acceptance criteria
2. Translate TASK-37 (RuboCop) via backlog task edit: title, description, all 5 ACs; watch whether the CLI renames the .md file when the title changes
3. Translate TASK-40 (tool result output) via backlog task edit: title, description, all 5 ACs
4. Translate TASK-45 (inotify/FSEvents wake-up) via backlog task edit: title, description, all 6 ACs
5. Verify: Cyrillic scan of backlog/tasks/*.md (content + filenames) shows zero Cyrillic in open task files; technical details (task numbers, RuboCop terms, offsets, wait_seconds, .locks, file paths, event symbols) preserved verbatim
6. Finalize per task-finalization guide, then commit including backlog/
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation evidence:
- AC1: TASK-37/40/45 titles, descriptions and all ACs (5+5+6) now English; verified via backlog task view. These tasks had no notes/comments (JSON: notes null, comments 0), so title+description+ACs was the full translation scope.
- AC2: Cyrillic content scan (grep -P [\x{0400}-\x{04FF}] over backlog/tasks/*.md) across all 11 open task files: 0 files with Cyrillic content. TASK-49's own description (which quoted the old Russian titles) was also translated for the scan to pass.
- AC3: every edit went through 'backlog task edit' (title/description/acceptance-criteria on TASK-37/40/45, description on TASK-49). No direct markdown edits.
- AC4: spot-check grep for 27 concrete technical details in the translated files — all present (TASK-36/22/8 refs, 554/513/21 rubocop numbers, rubocop -A, MAX_RESULT_LINES/CHARS, truncate_result, result_note, plural, 100 lines/4000 chars, wait_seconds, inotify/FSEvents/ctypes/self-pipe/wake-fd/watch-fd/.locks/SIGINT/SIGTERM/rb-fsevent, output_streamer_test.rb, pi_runner_test.rb, HH:MM:SS).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-04 07:27
---
Known limitation (decision need): the CLI does not rename task files on title change (verified empirically — task-37/40/45 .md filenames still carry the legacy Cyrillic slug) and offers no rename/move command (task --help: create/list/edit/view/archive/complete/demote only). Per the project rule, backlog files are CLI-only, so filenames were left as-is. AC2 is verified at the file-content level. If the filename slug should also become ASCII, that needs a follow-up: either a backlog.yml CLI feature or a documented exception. Not creating a task without approval.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Translated the three open Russian tasks (TASK-37 RuboCop, TASK-40 tool-result output, TASK-45 inotify/FSEvents wake-up) to English via the backlog CLI: titles, descriptions and 16 acceptance criteria (5+5+6); the tasks had no notes/comments. Also translated TASK-49's own description (it quoted the old Russian titles). Verified: (1) Cyrillic content scan over all 11 open task files -> 0 files with Cyrillic; (2) grep spot-check of 27 technical details (task refs, rubocop numbers, constants, paths, event symbols) -> all preserved; (3) all edits via 'backlog task edit', no direct markdown writes. Known limitation documented in a comment: CLI keeps legacy Cyrillic filenames (no rename command; files are CLI-only). Changes: backlog/tasks/task-37/40/45/49 markdown files.
<!-- SECTION:FINAL_SUMMARY:END -->
