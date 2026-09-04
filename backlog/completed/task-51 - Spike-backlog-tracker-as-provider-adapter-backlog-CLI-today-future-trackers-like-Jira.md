---
id: TASK-51
title: >-
  Spike: backlog tracker as provider adapter (backlog CLI today; future trackers
  like Jira)
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 07:11'
updated_date: '2026-09-04 07:38'
labels: []
dependencies:
  - TASK-50
type: spike
ordinal: 40000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design the adapter seam between the orchestrator and the task/backlog tracker (per user request: the backlog tracker should also be an adapter — Backlog.md via CLI today, other trackers possible later; there IS specificity, not fully generic yet).

Current state: Letsdo::BacklogTasks shells out via Open3 to 'backlog task list --assignee <handle> --exclude-status Done --json' (LETSDO_BACKLOG_COMMAND), returns Array<Hash> of open tasks or nil when the backlog is unreadable (CLI missing/failed/bad JSON). Letsdo::Loop already consumes a generic callable → Array (empty = none, nil = unreadable → pause+retry) — a good basis. Coupling: provider is hardwired to the backlog CLI and its JSON schema ('tasks' key, task fields).

Design goal: a TaskProvider interface (e.g. open_tasks(assignee) → normalized tasks | nil, preserving the empty-vs-unreadable semantics Loop relies on), a normalized task shape (id, title/status/assignee fields), BacklogTasks reframed as the backlog adapter over that interface, provider selection (env knob e.g. LETSDO_PROVIDER=backlog, default; injectable for tests). Future trackers (Jira/Linear/GitLab issues) described as developer tasks, NOT implemented here.

Coordinate with TASK-50 (target layout) and TASK-51 (same interface philosophy, adapter conventions). Deliverable: design documented in task comments + developer tasks (@developer) with ACs. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 TaskProvider interface specified, explicitly preserving empty-array (no tasks) vs nil (unreadable → retry) semantics used by Letsdo::Loop
- [x] #2 Normalized task shape defined; BacklogTasks mapped onto it as the backlog adapter (JSON schema differences handled inside the adapter)
- [x] #3 Provider registry/selection designed (env-driven, default backlog, injectable for tests); Loop/AgentLoop require no protocol change or the minimal delta is spelled out
- [x] #4 Future tracker adapters (Jira/Linear/GitLab) described as developer tasks with ACs — not implemented
- [x] #5 Spike leaves the code untouched (no commits, no file edits)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify the current provider chain in code: BacklogTasks (Open3 + JSON schema), Loop (callable Array/nil contract), AgentLoop#task_label (task["id"] — the only schema coupling), CLI wiring (run_agent_plain/tui hardwire BacklogTasks, LETSDO_BACKLOG_COMMAND), TUI Session#refresh (count only), Agent#run (task not passed to the run). Verify test seams: fake_backlog scenarios, backlog_tasks_test / loop_test / agent_loop_test / cli_test / tui_session_test. 2. Design: TaskProvider interface (call → Array<Task> | nil preserving Loop semantics), normalized Letsdo::Providers::Task shape, Providers::Backlog adapter mapping the backlog JSON schema, provider registry/selection (LETSDO_PROVIDER, default backlog, injectable for tests), spelling out the minimal Loop/AgentLoop delta. Coordinate with TASK-50 target layout and TASK-52 (providers/ vs backends/, LETSDO_PROVIDER vs LETSDO_BACKEND). 3. Record the design in task comments. 4. Create developer tasks (@developer, ACs): (a) providers/backlog.rb move + Task normalization + task_label delta; (b) LETSDO_PROVIDER selection via Config (TASK-53) + Builder (TASK-54); (c) roadmap task describing a second tracker adapter (Jira example), not implemented. 5. Backlog instructions task-finalization: verify each AC with evidence, final summary, Done, commit the backlog folder only (spike leaves code untouched).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: (1) design comment present in the task file — grep confirms all six sections (interface with empty-vs-nil semantics, normalized Task shape, backlog adapter mapping, registry/selection, sequencing/deltas, TASK-52 symmetry). (2) Developer tasks verified: TASK-56 (Providers::Backlog move + normalized Letsdo::Providers::Task, 6 ACs, dep TASK-42), TASK-58 (LETSDO_PROVIDER registry in Letsdo::CLI::Builder, 6 ACs, deps TASK-42/53/54/56), TASK-57 (roadmap: second tracker, Jira first, 4 ACs, dep TASK-56) — all Status To Do, Assignee @developer, referenced from TASK-51, in English (TASK-35). (3) Code untouched: git status shows only backlog/tasks/task-51 (modified) + task-56/57/58 (new) from this spike; all other working-tree changes (gemspec, lib/*, test/*, tui files, task-42) pre-existed from in-flight TASK-42 and are NOT staged. (4) Sequencing note: TASK-56 lands after TASK-42 (green baseline); TASK-58 after TASK-53/54 so Config owns LETSDO_PROVIDER and Builder owns the registry (per TASK-50 Phase-1 promise).
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-04 07:37
---
Design: task provider adapter seam (verified against code 2026-09-04, working tree incl. in-flight TASK-42)

CONSUMERS OF THE PROVIDER TODAY (verified)
- Letsdo::Loop: callable task_provider, semantics = Array (empty -> wait) vs nil (unreadable -> retry+wait). Element shape NOT touched — the loop only passes each task to run_task. Already generic, ZERO change (AC#3).
- Letsdo::AgentLoop#task_label: the ONLY business-layer consumer of a task field — reads task["id"] with fallback to task.to_s (one private method; the whole schema coupling).
- Letsdo::CLI#run_agent_plain/tui: construct Letsdo::BacklogTasks.new(handle:, command: LETSDO_BACKLOG_COMMAND, cwd: @root, env: ENV.to_h.merge(@env)) and pass -> { provider.call }.
- Tui::Session#refresh: -> { provider.call } -> count only, no field access.
- Letsdo::Agent#run: task is NOT passed into the run (run_one: ->(_task) { @agent.run }) — the normalized shape is also the future seam for per-task run context, out of scope today.
- Provider constructors/parsing (BacklogTasks): Open3 'backlog task list --assignee <handle> --exclude-status Done --json'; parses JSON["tasks"]; row keys id/title/status/priority/assignees; nil on ENOENT/non-zero/bad JSON/non-array tasks.

INTERFACE — Letsdo::Providers::TaskProvider (implicit, one method)
  #call -> Array<Letsdo::Providers::Task> | nil
      empty Array = no open tasks (Loop waits); nil = tracker unreadable (Loop retries). Semantics preserved EXACTLY as Letsdo::Loop relies on them (AC#1). Constructors keep binding the assignee handle (one agent <-> one handle, wiring-time knowledge) — the interface takes no per-call arguments, so the callable = -> { provider.call } contract stays identical.

NORMALIZED TASK SHAPE — Letsdo::Providers::Task (AC#2)
  Immutable value object: id, title, status, priority, assignees (attr_readers; assignees Array<String>). #to_s = id when present, else a readable summary (mirrors today's fallback-to-object in task_label). Only #id/#to_s are consumed today; title/status/priority/assignees are normalized for schema stability and future use (per-task run context, roadmap backend prompt). Adapters map their tracker's schema onto Task INSIDE the adapter; business layer never sees tracker JSON keys. Consumer delta: AgentLoop#task_label becomes task.to_s — one private method, message output byte-identical ('letsdo: running <name> for <task id>'); Loop untouched.

ADAPTER — Letsdo::Providers::Backlog (renamed/normalized BacklogTasks; file moves to lib/letsdo/providers/backlog.rb, the namespace TASK-50 reserved)
  Identical command line, injection points (handle/command/cwd/env), and rescue set (ENOENT, non-zero exit, JSON::ParserError, TypeError -> nil). Maps each JSON row onto Letsdo::Providers::Task. LETSDO_BACKLOG_COMMAND still honored (via Letsdo::Config after TASK-53).

SELECTION / REGISTRY (AC#3)
  Env knob LETSDO_PROVIDER, default 'backlog' — added to Letsdo::Config (TASK-53 seam, which reserved exactly this knob). Registry lives in the WIRING layer (Letsdo::CLI::Builder after TASK-54): PROVIDERS = { 'backlog' => ->(config) { Providers::Backlog.new(...) } }; unknown value -> stderr 'letsdo: unknown task provider: X' + exit 1 (fail fast, no silent fallback). Injectable for tests: Builder accepts a provider factory/registry override; absent LETSDO_PROVIDER -> backlog default -> existing cli_test fake_backlog tests pass unchanged. Loop/AgentLoop protocol change: none beyond the task_label line above.

SEQUENCING / DELTAS
  Dev task A (move+normalize): depends on TASK-42 (agent_loop.rb/cli.rb churn settles, green baseline); the cli.rb rename is a 2-line diff whether A lands before or after TASK-53/54. Dev task B (selection): depends on TASK-53 + TASK-54 + A (Config reads the knob, Builder owns the registry). Dev task C (roadmap): second tracker adapter spec, references A's interface, not scheduled.

SYMMETRY WITH TASK-52 (coordination)
  providers/ (TaskProvider) vs backends/ (backend session); LETSDO_PROVIDER vs LETSDO_BACKEND; both default to current behavior; both injectable; both map a product protocol onto normalized events/objects inside the adapter. Lays into TASK-50 target layout (Phase 2, namespaces reserved) with no layout conflict.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike complete: designed the task provider adapter seam. Verified the current chain in code (BacklogTasks Open3/JSON schema, Loop empty-vs-nil contract, AgentLoop#task_label as the only field consumer, CLI wiring, TUI count-only refresh). Design recorded as a task comment: TaskProvider interface (#call -> Array<Letsdo::Providers::Task> | nil preserving Loop semantics), normalized Letsdo::Providers::Task shape, Providers::Backlog adapter mapping the backlog JSON inside the adapter, LETSDO_PROVIDER registry in the wiring layer (default backlog, injectable, unknown value fails fast), minimal delta = one private method (task_label), symmetry with TASK-52 (providers/ vs backends/). Handed 3 developer tasks to @developer: TASK-56 (move+normalize, 6 ACs, dep TASK-42), TASK-58 (selection via Config+Builder, 6 ACs, deps 42/53/54/56), TASK-57 (roadmap: Jira first, 4 ACs, dep 56). Verified: design comment grep (all 6 sections), task views (To Do, @developer, ACs, English), git status shows only 4 backlog files from this spike — code untouched.
<!-- SECTION:FINAL_SUMMARY:END -->
