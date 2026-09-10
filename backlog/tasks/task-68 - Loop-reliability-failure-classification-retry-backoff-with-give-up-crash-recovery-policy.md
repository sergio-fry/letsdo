---
id: TASK-68
title: >-
  Loop reliability: failure classification, retry/backoff with give-up,
  crash-recovery policy
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 08:04'
updated_date: '2026-09-10 21:45'
labels: []
dependencies:
  - TASK-62
priority: medium
type: enhancement
ordinal: 57000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the loop-reliability design from TASK-62 (design comments 1-3 + requirements note; read them first). Today a failing task causes an immediate tight loop of agent runs (no backoff), a missing pi binary crashes letsdo with a Ruby backtrace, and crash recovery is implicit. This change: (1) classifies failures — provider-unreadable = pause+retry (unchanged), backend spawn error = controlled fail-fast exit 2, non-zero exit / exit-0-but-task-still-open = per-task retry with exponential backoff and give-up after N; (2) adds a small pure policy object (lib/letsdo/retry_policy.rb, injectable clock) wired at AgentLoop level — Letsdo::Loop stays generic and untouched; (3) keeps crash recovery agent-prompt-owned (In Progress tasks are re-run; the loop never resets tasks); (4) guarantees stop stays prompt during backoff cooldowns. Env knobs: LETSDO_MAX_RETRIES (default 3), LETSDO_RETRY_BASE (default = wait_seconds), LETSDO_RETRY_CAP (default 300). UX: give-up and backoff are stderr/TUI-log messages in English (TASK-35); README gets a short failure-handling section.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 With a task that always fails (non-zero exit), the loop runs it at most LETSDO_MAX_RETRIES (default 3) times per session with growing spacing between runs (first failure -> no immediate re-run; cooldown enforced via injectable clock), then stops attempting it for the session, logs 'giving up on <TASK>' to stderr, and keeps processing other open tasks; a fresh session resets the failure state
- [ ] #2 Backoff policy: after failure n the task is excluded from attempt batches until now >= now + min(BASE * 2^(n-1), CAP) with BASE=LETSDO_RETRY_BASE (default = wait_seconds), CAP=LETSDO_RETRY_CAP (default 300s); env knobs parsed in CLI with default fallback on invalid values (same pattern as wait_seconds); policy is a pure object with injectable clock; Letsdo::Loop is unchanged (no diff in lib/letsdo/loop.rb)
- [ ] #3 Failure signals: (1) non-zero exit counts as a failure; (2) exit 0 but the task is still open on the next provider poll counts as a failure; (3) a task absent from the provider after a run clears its retry state; a task skipped by cooldown is not re-recorded as failed
- [ ] #4 Missing/unexecutable backend (LETSDO_PI_COMMAND -> nonexistent binary): letsdo prints a clear message and exits 2 — no Ruby backtrace; new Letsdo::BackendUnavailableError in lib/letsdo/errors.rb raised from PiRunner/Agent on Process.spawn errno (ENOENT/EACCES)
- [ ] #5 Crash recovery regression: a task In Progress in the provider list is run normally (never reset by the loop); loop-side auto-reset/reassign/stuck-detection is NOT implemented in this change
- [ ] #6 Stop semantics unchanged and verified: SIGINT/SIGTERM during a backoff cooldown exits promptly with code 0; a started run is always terminated (TERM then KILL after grace) and reaped — regression tests cover both
- [ ] #7 Tests: RetryPolicy unit tests with a fake monotonic clock (backoff spacing, max-retries give-up, state clearing); AgentLoop integration with fake provider/run_one (tight-loop regression: no 4th run of the same task in a session); spawn-error test with a fake command; rake test green (0 failures); rubocop 0 offenses
- [ ] #8 README documents the failure-handling behavior and the 3 env knobs (LETSDO_MAX_RETRIES, LETSDO_RETRY_BASE, LETSDO_RETRY_CAP); all new UI/text in English (TASK-35)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation complete and verified. All 8 acceptance criteria met. rake test: 288 runs, 824 assertions, 0 failures, 0 errors. rubocop 1.77.0: 60 files inspected, 0 offenses. README updated with failure-handling section + 3 env knobs; docs/config.md updated for consistency.

Files: lib/letsdo/retry_policy.rb (new), lib/letsdo/errors.rb (BackendUnavailableError), lib/letsdo/agent_loop.rb/tasks.rb (wiring + reconcile+filter), lib/letsdo/backends/pi.rb (spawn errno rescue), lib/letsdo/cli.rb (rescue exit 2), lib/letsdo/cli/builder.rb (retry_options), lib/letsdo/config.rb (3 knobs + invalid fallback), lib/letsdo.rb (require). Tests: test/retry_policy_test.rb (new), test/agent_loop_test.rb (retry integration), test/backends/pi_test.rb (spawn error), test/cli_test.rb (exit 2), test/config_test.rb (invalid fallback). Loop unchanged per AC #2.
<!-- SECTION:NOTES:END -->
