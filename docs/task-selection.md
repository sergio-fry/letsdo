# letsdo — task selection: feasibility and requirements

This document is the outcome of TASK-86: can the next task an agent should
pick up be selected programmatically and algorithmically? It records how
selection works today, which criteria an algorithm would use, what data is
missing, the risks and edge cases, a sketch of a possible approach, and the
recommendation.

- [Summary](#summary)
- [How selection works today](#how-selection-works-today)
- [Selection criteria](#selection-criteria)
- [Missing data](#missing-data)
- [Risks, limitations, edge cases](#risks-limitations-edge-cases)
- [Possible approaches](#possible-approaches)
- [Recommendation](#recommendation)
- [Out of scope](#out-of-scope)

## Summary

Selection today is **LLM-driven, not algorithmic**. `Letsdo::Loop` receives a
batch of open tasks and runs the agent once per batch element, but the task
object it holds is discarded before the run: the agent re-queries the backlog
inside its own prompt and decides which task to work. letsdo never enforces
the batch order it just read.

The backlog CLI already exposes the primitives needed for deterministic
selection (`--sort priority`, `--ready`, `--type`, `--labels`, `--limit`), and
`Letsdo::Providers::Backlog` uses none of them. The recommendation is to build
a **small, scoped deterministic-ordering change** (scope A below): request a
priority-sorted, ready-only batch and keep the fields the selector needs. Do
**not** build a cross-agent scheduler (scope C); task injection into the
prompt (scope B) is a documented follow-up that needs its own decision because
it changes the agent contract.

**Status: scope A is implemented (TASK-95).** The provider now requests
`--ready --sort priority` and sorts the normalized batch in the adapter (In
Progress first, then priority, then ordinal, then id), so the run order it
hands to the loop is the authoritative one. The analysis below is kept as the
record; scopes B and C remain out of scope.

## How selection works today

End-to-end, one `letsdo <name>` session:

1. `Letsdo::Providers::Backlog` runs
   `backlog task list --exclude-status Done --ready
   --sort priority --json` (`lib/letsdo/providers/backlog.rb`,
   `#command_line`) — the CLI line carries no `--assignee` (backlog CLI
   matches it by exact string, which made notation drift invisible) — and
   matches the agent's assignee on the returned tasks in Ruby
   (`#normalized` comparison of the stored values against the resolved
   handle). `--ready` drops tasks whose dependencies are not all
   done; `--sort priority` orders by priority then ordinal as a first pass.
2. The adapter projects each raw task onto `TASK_FIELDS =
   %w[id title status priority assignees ordinal type labels milestone]` and
   drops `reporter`, `parentTaskId`, `createdAt`, `updatedAt` and everything
   else. It then sorts the batch itself, because the CLI does not put In
   Progress first: In Progress first, then priority High > Medium > Low, then
   ordinal ascending, then id ascending. The batch the provider returns is
   therefore the authoritative run order (TASK-95).
3. `Letsdo::Loop#run_batch` (`lib/letsdo/loop.rb`) iterates the batch once and
   calls `@run_task.call(task)` for each element. The provider is **not**
   re-polled between the runs of one batch.
4. `Letsdo::AgentLoop#run_one_task` (`lib/letsdo/agent_loop/tasks.rb`) logs
   the task label and calls the runner. Its default runner is
   `->(_task) { @agent.run }` (`lib/letsdo/agent_loop.rb`, `#assign_opts`) —
   **the task object is thrown away**.
5. `Letsdo::Agent#run` (`lib/letsdo/agent.rb`) takes no task argument. It
   prepends the injected identity and hands the prompt to pi. The prompt is
   what chooses the task: `agents/analyst.md` and `agents/developer.md`
   instruct the agent to run
   `backlog task list --assignee <name> --exclude-status Done --sort priority --plain`
   and take the first task, with the "already In Progress first" and "if
   blocked, take the blocker" exceptions.
6. Retry state lives in `Letsdo::RetryPolicy` and is keyed on the **batch
   element** passed to `run_one_task` (`@last_attempted[task_key(task)]`),
   then reconciled against the next provider batch. It is not keyed on the
   task the agent actually worked.

So the authority over "which task next" sits in the prompt, and letsdo's own
batch is only a run counter. The order letsdo read does not govern the work.

## Selection criteria

A deterministic selector needs these inputs, in this order:

1. **Eligibility**
   - assignee contains the agent's assignee (`Config#assignee_handle`,
     default `<name>`, the canonical bare name); other agents' and `human`
     tasks are never auto-run.
   - `status != Done`.
   - not in retry cooldown and not given up for this session
     (`RetryPolicy#cooldown?` / `#gave_up?`).
   - dependencies satisfied (all blocking tasks done).
2. **Ordering**
   - `In Progress` first: a task already started by this agent resumes before
     a new task starts (the prompt's existing rule 3).
   - `priority`: High > Medium > Low.
   - **tie-break: `ordinal` ascending, then `id` ascending.** Equal priority
     is the common case (all three open tasks in this repo are Medium), so the
     tie-break is not optional — without it the order is unstable. The backlog
     CLI's `--sort priority` already orders same-priority tasks by ordinal
     ascending (verified: TASK-86 ordinal 75000 before TASK-89 ordinal 78000).
3. **Optional routing inputs** (only if per-agent routing is wanted later)
   - `type` (`spike`, `bug`, `feature`, `chore`, `docs`, `task`) — e.g. the
     analyst takes spikes, the developer takes bugs/features.
   - `labels` / `milestone` — team-defined tags usable as capability filters.
   - `parentTaskId` — subtask ordering, if subtasks ever become selectable
     units.
4. **Load**
   - number of open tasks runnable by this agent, or per-agent concurrency.
     This criterion is **not implementable in the current design**: each agent
     runs as its own process and the backlog is the only shared state, so no
     process can see another's queue or in-flight work.

## Missing data

| Gap | Where | Impact |
| --- | --- | --- |
| No sort requested | `Providers::Backlog#command_line` | Resolved in TASK-95: the command requests `--sort priority` and the adapter applies the full In-Progress-first tie-break. |
| No readiness filter | same | Resolved in TASK-95: the command requests `--ready`, so blocked tasks never reach the loop. |
| `type`, `ordinal`, `labels`, `milestone` dropped | `TASK_FIELDS` | Resolved in TASK-95: all four are normalized onto `Task`. |
| `dependencies` absent from list JSON | backlog `task list --json` | Blocked state is not a field; the provider relies on the `--ready` filter instead of N per-task `backlog task <id> --json` calls. |
| Task object discarded before the run | `AgentLoop#assign_opts` + `Agent#run` | letsdo cannot force the task it selected; the LLM re-selects and can diverge from the batch element (see risks). |
| No machine-readable agent capabilities | `agents/<name>.md` front matter (only `model` is consumed, `lib/letsdo/agent.rb`) | Type/skill routing exists only as prose in the prompt, not as data. The front-matter block is the natural place to add `types:` / `skills:`. |
| No claim/lock | backlog only | Two agents (or two processes of the same agent) can race for the same unassigned task; a status update is not atomic. |
| No selection telemetry | `Metrics` records provider counts and run outcomes | There is no record of which task was selected, on which basis, or why a task was skipped. |

## Risks, limitations, edge cases

- **Equal priority.** Must be resolved deterministically. Use `ordinal`, then
  `id`; do not rely on the raw CLI order.
- **Blocked top task.** If the highest-priority task is blocked, the selector
  must skip it. The prompt's current rule ("take the blocker") is ambiguous
  for an algorithm: if the blocker is assigned to this agent, selecting the
  blocker is correct; if it is another agent's task, that would violate the
  "do not take work that is not assigned to you" rule, so the selector must
  fall through to the next runnable task and surface the skip.
- **Transitive and stale dependencies.** `--ready` is documented as
  "unblocked tasks with all dependencies completed" — rely on the CLI rather
  than reimplementing graph traversal locally. A dangling dependency id
  (blocker deleted/archived) may make a task permanently "not ready"; the
  session should make that visible (a `--ready`/blocked count in the log)
  instead of silently never running it.
- **Batch order vs. prompt order (the real defect).** The loop runs the agent
  once per batch element without re-polling. If the batch is
  `[B(Low), A(High)]` and run 1 does not close `A`, run 2 runs for batch
  element `B` while the agent again selects `A`. `B` starves and the retry
  accounting misattributes a failure to `B` (which was never worked) while
  `A` is not cooled down. Aligning the provider order with the prompt order
  fixes the common case; only task injection (scope B) fixes it absolutely.
- **New work during a batch.** Because the provider is polled once per batch,
  a High task created mid-batch cannot preempt it; it is picked up after the
  current batch drains. Acceptable for short runs; note it if runs get long.
- **Race conditions.** Unassigned tasks are a coordination gap: two agents can
  pick the same task. The design's answer is assignment by a human
  (`developer`, `analyst`, `human`), not a lock. A lock/claim mechanism
  would require shared mutable state and belongs to scope C, not here.
- **Retry interaction.** Any selector must compose with `RetryPolicy`: a task
  in cooldown or given up must not be re-offered, and the outcome must be
  recorded against the task that was actually selected.
- **Scope creep.** "Algorithmic selection" can silently grow into a central
  scheduler with a queue, locks, load balancing and preemption. That is a
  different architecture (shared coordinator) from letsdo's "one process per
  agent, backlog is the only shared state" model and should not be smuggled
  into this change.

## Possible approaches

### A. Provider-side deterministic ordering (small)

Make the provider return the batch in authoritative order and keep the fields
a selector needs:

- request `--ready --sort priority` in
  `Providers::Backlog#command_line`;
- extend `TASK_FIELDS` with `type`, `ordinal`, `labels`, `milestone`;
- order in the selector/provider as: In Progress first, then priority, then
  ordinal, then id (the CLI sorts by priority+ordinal but does not put In
  Progress first — verified: `--ready --sort priority` returned the In
  Progress task first here only because its ordinal is lower);
- `Letsdo::Loop` stays generic; no prompt or `Agent` signature change.

Pros: small, no agent-contract change, testable against the fake backlog, uses
documented CLI features. Cons: the agent still re-selects inside its prompt,
so letsdo's batch order is only advisory and the failure/accounting defect in
the risks section narrows but is not eliminated.

### B. Selector + task injection (medium)

Build on A: a pure `Letsdo::Selection` object computes the next runnable task,
and letsdo passes it into the run so the agent does not re-select:

- `Agent#run(task:)` injects "your task for this run is `<id>` — `<title>`"
  into the prompt;
- the prompts' "Choosing a task" section is replaced by "work the task letsdo
  handed you" (the blocker/readiness logic moves into the selector);
- `AgentLoop` records retry outcomes against the injected task.

Pros: one run = one task becomes enforced, not advisory; retry accounting and
starvation are fixed; per-agent `types:`/`skills:` front matter routing becomes
possible. Cons: changes the agent contract and both prompt files; needs its own
decision, prompt tests and a transition for custom prompts that still
self-select.

### C. Central scheduler (large, not recommended)

A coordinator process with a shared queue, atomic claim/lock, per-agent load
balancing and preemption.

Pros: true multi-agent scheduling. Cons: introduces shared mutable state,
concurrency, a new failure domain and an operational component; contradicts the
project's stated design ("multiple agents run as separate processes ... they
coordinate through the shared backlog — nothing else in common", README). Not
justified by any observed failure.

## Recommendation

**Build it — to scope A.** Add deterministic ordering and readiness to the
provider: `--ready --sort priority`, the missing normalized fields, and the
explicit In-Progress→priority→ordinal→id order. It is small, low-risk, uses
existing backlog CLI features, needs no prompt or agent-contract change, and
removes the common divergence between the order letsdo reads and the order the
agent picks. **Implemented in TASK-95** (`Providers::Backlog#command_line` and
`#sort`, `Providers::Task` fields).

Record scopes **B and C as out of scope for now**. B (task injection into the
prompt) is the correct way to fully enforce the batch and fix retry
misattribution, but it changes the agent contract and both prompt files and
deserves a separate decision once A is in use. C (central scheduler) is
explicitly rejected: it conflicts with the backlog-only, one-process-per-agent
architecture and is not justified by current pain.

The follow-up implementation task for scope A is tracked as TASK-95
(`Deterministic task selection: priority-sorted, ready-only provider batch`).

## Out of scope

- Task injection into the agent prompt and the prompt rewrite (scope B).
- Per-agent `types:`/`skills:` front-matter routing (needs B's injection to be
  enforceable).
- Cross-agent load balancing, shared queue, atomic claim/lock, preemption
  (scope C).
- Subtask-level selection and milestone-driven scheduling.
