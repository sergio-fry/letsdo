---
id: TASK-91
title: >-
  Bug: Providers::Backlog crashes on real backlog JSON — Task.new(**fields)
  rejects unknown keys
status: Done
assignee:
  - '@developer'
created_date: '2026-09-13 11:36'
updated_date: '2026-09-13 12:09'
labels: []
dependencies: []
references:
  - lib/letsdo/providers/backlog.rb
  - lib/letsdo/providers/task.rb
  - test/providers/backlog_test.rb
priority: high
type: bug
ordinal: 80000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Running `./bin/letsdo developer` aborts immediately instead of processing tasks:

```
letsdo: session: 0 done, 0 failed, 0 interrupted, unknown left open, 1s (0s in runs, 1s waiting, avg 0s)
/mnt/storage/projects/letsdo/lib/letsdo/providers/task.rb:12:in Letsdo::Providers::Task#initialize: unknown keywords: :type, :reporter, :labels, :milestone, :parentTaskId, :ordinal, :createdAt, :updatedAt (ArgumentError)
    caller: /mnt/storage/projects/letsdo/lib/letsdo/providers/backlog.rb:44
    |  tasks.is_a?(Array) ? tasks.map { |t| Task.new(**t.transform_keys(&:to_sym)) } : nil
    callee: /mnt/storage/projects/letsdo/lib/letsdo/providers/task.rb:12
    |  def initialize(id:, title: nil, status: nil, priority: nil, assignees: [])
```

Cause: the adapter blindly splats every key of every task object from `backlog task list --json` into the keyword-only `Letsdo::Providers::Task` constructor, while `Task` accepts only `id, title, status, priority, assignees`. The real backlog CLI returns the full task schema, e.g.:

```json
{"id":"TASK-10","title":"...","status":"Done","type":"feature","priority":"high","assignees":["@developer"],"reporter":null,"labels":[],"milestone":null,"parentTaskId":null,"ordinal":1000,"createdAt":"...","updatedAt":"..."}
```

Why it matters: this is a hard crash on the first read of the real tracker — the primary happy path of the tool is broken in production, yet the provider test suite passes because its fake data only contains the normalized subset of keys. It also breaks the documented provider contract: an unreadable/unsupported backlog response must yield `nil` (pause and retry) rather than propagate an exception out of the loop.

Scope:
- `lib/letsdo/providers/backlog.rb` — mapping of raw CLI JSON onto `Letsdo::Providers::Task`.
- `lib/letsdo/providers/task.rb` — the normalized shape and what it must tolerate.
- `test/providers/backlog_test.rb` + `test/fixtures/fake_backlog` — fixtures must reflect the real CLI schema.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Running an agent session (`./bin/letsdo developer`) with the real backlog CLI installed starts the loop without raising on task parsing
- [x] #2 The Backlog provider maps only the normalized fields (id, title, status, priority, assignees) and tolerates unknown/extra JSON keys
- [x] #3 A task JSON payload with the full real schema (type, reporter, labels, milestone, parentTaskId, ordinal, createdAt, updatedAt) parses into a Task without error
- [x] #4 Missing optional fields (title, status, priority, assignees) still parse, and a nil/absent id keeps the documented to_s fallback to title
- [x] #5 Malformed or unexpected payloads (non-JSON, missing tasks key, tasks not an array, CLI failure) still return nil so the loop pauses instead of crashing
- [x] #6 Regression test covers the full real-schema payload; the fake backlog fixture reflects the real CLI output
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Project raw CLI tasks onto the normalized shape in `Providers::Backlog#call`: whitelist `id/title/status/priority/assignees` and ignore every other JSON key (type, reporter, labels, milestone, parentTaskId, ordinal, createdAt, updatedAt), instead of splatting the whole hash into `Task.new`.
2. Keep unreadable payloads returning `nil`: CLI failure, `Errno::ENOENT`, non-JSON, missing `tasks` key, `tasks` not an array, and non-Hash task entries (TypeError).
3. Document in `Providers::Task` that the adapter is responsible for projecting tracker payloads onto the normalized shape, so Task stays strict keyword-only.
4. Make `test/fixtures/fake_backlog` emit the real full task schema in the `open` scenario and add `sparse` (missing optional fields, absent id) and `weird` (non-object entry) scenarios.
5. Regression tests in `test/providers/backlog_test.rb`: full-schema payload parses with normalized fields and ignores extra keys; sparse payload parses with `to_s` title fallback; weird payload returns nil.
6. Verify: full `rake test`, plus a live repro against the real `backlog task list --json` payload that crashed before.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Verification evidence:
- Pre-fix repro (real payload shape through the provider): RAISED ArgumentError unknown keywords: :type, :reporter, :labels, :milestone, :parentTaskId, :ordinal, :createdAt, :updatedAt. Post-fix the same repro returns normalised Tasks.
- End-to-end against the real backlog CLI: TERM=dumb LETSDO_PI_COMMAND=test/fixtures/fake_pi LETSDO_WAIT_SECONDS=2 timeout 20 ./bin/letsdo developer -> 'letsdo: developer has 6 open task(s)', 18 runs, no ArgumentError (bounded by timeout, as expected for a polling loop).
- ruby -Ilib -Itest test/providers/backlog_test.rb -> 15 runs, 30 assertions, 0 failures, 0 errors.
- Whole suite run file by file: all green except two pre-existing issues proven unrelated: test/cli_builder_test.rb#test_tui_run_engages_through_the_builder fails identically at baseline (with this task's files stashed), and test/cli_test.rb hangs in CliTuiTest#test_tui_pause_then_quit_terminates_the_pi_cleanly with this task's files stashed and passes at HEAD in a clean worktree, so both come from other uncommitted in-flight work, not this fix.
- Decision: the adapter projects explicitly (TASK_FIELDS whitelist) instead of Task tolerating arbitrary keywords, so a growing CLI schema can never crash the loop and a wrong keyword stays a programming error.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Providers::Backlog now projects raw backlog CLI tasks onto the normalized Task shape (TASK_FIELDS: id/title/status/priority/assignees) instead of splatting every JSON key into Task.new, so extra CLI fields (type, reporter, labels, milestone, parentTaskId, ordinal, createdAt, updatedAt) are ignored. Non-Hash task entries raise TypeError through the existing rescue, so unreadable payloads still return nil and the loop pauses. Task gained a doc note that the adapter owns projection; the fake backlog fixture now emits the real full schema and added sparse/weird scenarios, with regression tests for full-schema, missing-optional-fields and non-object entries. Verified with a pre-fix repro, an end-to-end ./bin/letsdo developer run against the real CLI, and the provider test file (15 runs, 30 assertions, 0 failures).
<!-- SECTION:FINAL_SUMMARY:END -->
