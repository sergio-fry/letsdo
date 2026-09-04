
<!-- BACKLOG.MD GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.50.1 -->
<CRITICAL_INSTRUCTION>

## Backlog.md Workflow

This project uses Backlog.md for task and project management.

**For every user request in this project, run `backlog instructions overview` before answering or taking action.**

Use the overview to decide whether to search, read, create, or update Backlog tasks.

Before task lifecycle actions, read the matching detailed guide:
- `backlog instructions task-creation` before creating or splitting tasks
- `backlog instructions task-execution` before planning, changing status or assignee, adding a plan or implementation notes, or implementing task work
- `backlog instructions task-finalization` before checking acceptance criteria, writing final summaries, or moving tasks to terminal statuses

Use `backlog <command> --help` before running unfamiliar commands. Help shows options, fields, and examples.

Do not edit Backlog task, draft, document, decision, or milestone markdown files directly. Use the `backlog` CLI so metadata, relationships, and history stay consistent.

</CRITICAL_INSTRUCTION>
<!-- BACKLOG.MD GUIDELINES END -->

## Conventions

**Task tracking is done in English.** All tracked artifacts — task titles and
descriptions, acceptance criteria, notes and comments, drafts, milestones,
decisions, and backlog documentation — are written in English.

Why: consistency across the project (the English-only convention was
established in TASK-35), open-source readiness (a readable, uniform backlog
lowers the barrier for external contributors), and one language inside every
tracked artifact instead of a mix. The rule matches the project convention and
applies only to tracked artifacts; user conversations may stay in any language.
Existing backlog history (tasks already written in Russian, open or closed) is
left as-is — this rule governs new and edited entries only.

**No scratch/debug files in the repo.** When capturing command output for
debugging (test runs, backtraces, TUI frames), redirect to `/tmp` — never write
capture files like `*.txt` or `.test_report.txt` into the repository root.
Tests must not create files in the repo root either; temporary test output
belongs under `/tmp` or a tmpdir. (Established after debug artifacts polluted
the repo during TASK-42.)

**Every backlog task must carry a priority (High / Medium / Low).** Set it at
task creation: `backlog task create ... --priority High|Medium|Low`. When the
creator does not choose, the default is Medium. Why: agent workers pick tasks
from the priority-sorted queue (`backlog task list --sort priority`, ties
broken by ordinal), so a task left without a priority silently falls to the
bottom of the queue — the recurring mis-ordering this rule fixes (2026-09-04).
The rule applies to all new and edited tasks; existing open tasks were
backfilled to Medium.

Canonical project description (single source of truth — reused by the README,
gemspec, and project rules):

> A local agent worker for Backlog.md/markdown tasks.
