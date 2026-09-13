# letsdo — prompt-authoring guide

An agent in letsdo is exactly one file: `agents/<name>.md`. The file is the
agent's whole identity — role, rules, workflow. The assignee handle is
derived from the name (`agents/developer.md` ⇄ `@developer`), so the agent
automatically works on the tasks already assigned to it. Adding a file
creates an agent; no code, no schemas, no setup.

This guide covers what a good agent prompt contains, what to avoid, and two
worked examples from this repository's own agents.

- [How letsdo uses the prompt](#how-letsdo-uses-the-prompt)
- [Must-haves](#must-haves)
- [Anti-patterns](#anti-patterns)
- [Worked examples](#worked-examples)
- [Checklist](#checklist)

## How letsdo uses the prompt

- The prompt is read on every run from `<LETSDO_ROOT>/agents/<name>.md` and
  handed to pi as the agent's system prompt (`pi --mode json`).
- Before the prompt is handed over, letsdo prepends the agent's identity —
  its name and backlog assignee handle (`Config#assignee_handle`, default
  `@<name>`) — to it. The injection always happens, whatever the template
  contains, so a template never has to state the name or handle.
- When the file is missing, the agent runs on the built-in default prompt
  (process-only instructions); letsdo announces where it looked and how to
  create a prompt (`letsdo <name> --init`).
- The pipeline is deterministic per run: one run = one agent invocation =
  one task. The prompt defines HOW the agent executes that task.

## Must-haves

A robust agent prompt has these parts:

1. **Identity.** The agent's identity — its name and backlog assignee
   handle — is injected by letsdo at the top of every prompt, so the
   template does not have to state it. A hardcoded handle is a bad idea:
   it drifts from `AGENT_ASSIGNEE_HANDLE` and the backlog assignment. You
   can still describe the role in prose; keep the name in the prompt
   matching the file name.

2. **Exactly one task per run.** The main rule. The agent picks up and
   completes exactly one assigned task, then stops. This is what keeps an
   orchestrator loop honest: no context-switching, no runaway churn.

   ```
   ## Main rule: exactly one task per run
   In a single run you pick up and complete exactly one task assigned to
   you, then stop. You take the next task only in the next run.
   ```

3. **What to do when there are no tasks.** The corollary of the one-task
   rule: an agent must *not* invent work or create tasks itself.

   ```
   If there are no tasks assigned to you — do not invent work and do not
   create tasks yourself. End the run with a message that there are no
   tasks.
   ```

4. **How to choose a task.** Be explicit about the selection order, because
   the agent will face multiple open tasks:

   ```
   Take the highest priority task assigned to you in order:
   0. if a task is already in progress
   1. priority
   2. order (ordinal), if priorities are equal
   If the chosen task is currently blocked, take the task that blocks it.
   ```

5. **An execution protocol.** Step-by-step instruction for the lifecycle of
   a task: read the instructions, start (status + assign to yourself), plan,
   record progress as you go, verify and finish, commit. Reference the
   project's actual commands and guides (`backlog instructions
   task-execution`, `backlog instructions task-finalization`, ...) — the
   agent executes them literally.

6. **Deliverables.** What the final result must look like — concrete
   artifacts: implementation tasks for the developer with acceptance
   criteria, documentation files, recorded decisions. Name file paths and
   commands.

7. **Style and language rules.** Project conventions the agent must follow
   in every artifact it writes (for example English-only task tracking).
   State them as a hard rule, not a suggestion.

8. **Prohibitions.** What the agent must never do — explicitly. The most
   valuable one in a multi-agent system: *do not take work that is not
   assigned to you* and *do not complete several tasks in one run*.

## Anti-patterns

- **Multi-task runs.** "Work through all open tasks" defeats the loop
  design: one task per run is the contract that makes progress observable
  and stops possible.
- **Inventing work.** No task → done, not "let me also fix wiring/". A
  worker without an explicit no-invent rule will drift off the backlog.
- **Vague instructions.** "Improve the code" — improve what, where, how
  will we know it worked? Name files, components, commands and exit
  criteria. The agent's job is execution, not guessing intent.
- **No stop condition.** A prompt without a finish ("end the run with a
  message when there are no tasks") produces an agent that never knows it
  is done.
- **Keeping state only in the head.** Long tasks fail when intermediate
  results live only in the conversation. The prompt must require recording
  (task notes, comments) as it goes.
- **Untestable acceptance criteria.** "Works well" cannot be verified.
  Prefer testable, objective criteria ("`rake test` green, 0 failures",
  "the created task is assigned to @developer").
- **Missing identity/role.** Without a role the agent cannot tell what it
  owns. letsdo injects the name and handle, but the role and rules are the
  template's job.
- **Mixing languages in tracked artifacts.** In this project the convention
  is English for tasks, notes, decisions and docs (TASK-35/48) even though
  conversations may be in any language. State the convention; do not rely
  on osmosis.

## Worked examples

Both examples are real agents of this repository: `agents/developer.md` and
`agents/analyst.md`.

### agents/developer.md — the implementer

Structure: identity → main rule → task selection → execution protocol →
prohibitions.

- **Identity + main rule:** "You are a developer agent named developer",
  then exactly-one-task-per-run with the no-tasks rule.
- **Task selection:** the priority → ordinal ladder, with the blocked-task
  rule (take the blocker into work).
- **Execution protocol:** read `backlog instructions task-execution` first;
  move the task to In Progress and assign it to yourself; draft a plan and
  record it; implement in short iterations with progress in task notes;
  on completion verify every acceptance criterion with objective evidence,
  write a final summary and move the task to Done; commit the changes
  including the backlog folder.
- **Prohibitions:** no unassigned work, no several tasks in one run.

### agents/analyst.md — the designer

Same skeleton, different deliverables: identity, main rule, task selection,
then an analysis protocol (start → plan → research → record rationale in
task notes/comments → produce deliverables) and a finalization protocol
(verify each acceptance criterion with objective evidence, mark completed
items, final summary, Done, commit). The analyst's "deliverables" step is
the interesting part — it says documentation deliverables are written into
the repo (`backlog doc/decision`), reference them from the task, and
implementation work is handed to the developer as new tasks: clear title,
description, testable acceptance criteria, affected components. Both agents
end with the same prohibitions and an explicit language/style section.

The pattern to copy: **identity → one task per run → selection → protocol
with concrete commands → deliverables → style rule → prohibitions.**

## Checklist

Before writing `agents/<name>.md`, check:

- [ ] Role described in prose (the name/handle identity block is injected
      by letsdo).
- [ ] Main rule: exactly one task per run.
- [ ] No-tasks rule: do not invent work, do not create tasks.
- [ ] Task selection: in progress → priority → ordinal; blocked → take the
      blocker.
- [ ] Execution protocol with the project's real commands and guides.
- [ ] Deliverables: concrete artifacts, paths, acceptance criteria.
- [ ] Style/language conventions for tracked artifacts.
- [ ] Prohibitions (unassigned work, several tasks per run, ...).
- [ ] Prompt matches the file name (`<name>.md` ⇄ `@<name>`).