# letsdo — usage guide

This guide walks through running letsdo end to end: prerequisites, install,
the first run, what a session looks like (plain line-stream and TUI), the
orchestrator loop semantics, and how to run several agents at once.

- [Prerequisites](#prerequisites)
- [Install](#install)
- [Project layout](#project-layout)
- [First run](#first-run)
- [A session in plain mode](#a-session-in-plain-mode)
- [The interactive TUI](#the-interactive-tui)
- [How the loop behaves](#how-the-loop-behaves)
- [Running several agents](#running-several-agents)
- [Environment self-check (doctor)](#environment-self-check-doctor)
- [Exit codes](#exit-codes)
- [Next steps](#next-steps)

## Prerequisites

- **Ruby >= 3.0**.
- The **pi agent CLI** on `PATH` — the AI backend that actually runs each
  agent (`pi --mode json`). Override the command with `LETSDO_PI_COMMAND`
  (see the [configuration reference](config.md)).
- The **Backlog.md CLI** (`backlog`) on `PATH` — the task provider reads the
  runnable open tasks assigned to an agent via
  `backlog task list --exclude-status Done --ready --sort priority` (the
  assignee is matched on the returned tasks; the CLI line stays bare). Override
  with `LETSDO_BACKLOG_COMMAND`.

Tests and the gem build use only Ruby's bundled default gems (Minitest,
Rake) — no `bundle install` needed.

## Install

Build and install the gem from the repository:

```sh
git clone git@github.com:sergio-fry/letsdo.git
cd letsdo
gem build letsdo.gemspec
gem install letsdo-0.3.0.gem
```

> **Ruby 4.0.x note.** Some Ruby 4.0.x builds ship default gems out of sync —
> rdoc 8.0.0 declares `rbs >= 4.0.0` while rbs 3.x is bundled — so the
> post-install RDoc hook can raise `Gem::ConflictError` even though the gem
> files are already installed. Fix the environment by installing a matching
> rbs first (`gem install rbs -v '>= 4.0.0'`); if that is not possible,
> install the gem without documentation to skip the hook
> (`gem install letsdo-0.3.0.gem --no-document`).

Or run it straight from the checkout without installing:

```sh
cd letsdo
./bin/letsdo --version
```

## Project layout

letsdo works in a Backlog.md project root — a folder that holds your
`backlog/` tasks and your `agents/` prompts:

```
your-backlog-project/
├── backlog/            # the Backlog.md tasks (the single source of truth)
├── agents/             # one prompt file per agent: agents/<name>.md
└── ...                 # anything else — docs, code, etc.
```

The project root defaults to the current working directory and can be set
explicitly with `LETSDO_ROOT`.

## First run

An agent is just a prompt file. Create one, then run the agent:

```sh
cd your-backlog-project

# Option 1: scaffold a starter prompt, then customize it
letsdo developer --init           # writes agents/developer.md, never runs the agent

# Option 2: write agents/developer.md by hand
# (see the prompt-authoring guide for what a good prompt contains)

# Run the agent: it works through all open tasks assigned to developer
letsdo developer
```

No prompt file yet? The agent still runs on the built-in default prompt and
letsdo tells you once how to create your own:

```
$ letsdo newcomer
letsdo: no prompt for newcomer at /home/user/backlog-project/agents/newcomer.md
letsdo: using the built-in default prompt (create a prompt file with 'letsdo newcomer --init')
```

`--init` never overwrites an existing prompt and never runs the agent: it
fails with exit 1 when `agents/<name>.md` already exists or the name is
unsafe (contains `/` or `\`, or is `.`/`..` — nothing is ever written
outside `agents/`). Both argument orders work: `letsdo <name> --init` and
`letsdo --init <name>`.

## A session in plain mode

When stdout is **not** a terminal (pipes, CI, `TERM=dumb`), letsdo prints a
plain line stream:

- **stdout** — only the agent's answer text, as it is generated.
- **stderr** — service and tool lines with a shared `HH:MM:SS` prefix:

  ```
  HH:MM:SS ⚙ tool_name: arguments     tool call (bash → the command, read/write/edit → the path)
  HH:MM:SS ✓ tool_name: done (3s)     tool completion, success
  HH:MM:SS ✖ tool_name: error (3s)    tool completion, error
  ```

  Tool result bodies are never printed — the call line and its one-line
  completion are the whole tool story, so the stream stays readable.

- Loop service messages on stderr, e.g.:

  ```
  letsdo: developer has 3 open task(s)
  letsdo: running developer for TASK-42
  letsdo: no open tasks for developer, retrying in 10s
  letsdo: backlog unavailable, retrying in 10s - run `letsdo doctor` to diagnose
  letsdo: stopped
  ```

  When the backlog stays unreadable, only the first message of a run
  carries the `letsdo doctor` hint; later retries repeat the short line.

Stop the loop with `Ctrl+C` (`SIGINT`; `SIGTERM` and `SIGHUP` — terminal
closed — work too) — a running pi child is terminated and the process
exits with code 0. With `LETSDO_DEBUG=1` the loop additionally traces
`[letsdo] loop: ...` decisions to stderr.

### Pause and quit in plain mode

When stdin is still a terminal (for example `letsdo developer > run.log`,
where stdout is redirected but the keyboard is live), plain mode reads the
same control keys as the TUI:

| Key | Action |
| --- | --- |
| `p` | pause/resume: mid-run the running pi child is suspended at the kernel level (SIGSTOP); a second `p` resumes it (SIGCONT). Between runs the next task is held until resume. A no-op when nothing is running |
| `q` | stop — identical to `Ctrl+C`: the pi child is terminated, the process exits with code 0 |

The control reader writes nothing, so the plain stream stays
byte-identical (no escape codes, no echoed input). When stdin is **not** a
terminal (a pipe, `</dev/null`, CI), the reader is never started and the
loop is stopped only by `SIGINT`/`SIGTERM`/`SIGHUP`.

## The interactive TUI

When stdout **and** stdin are terminals and `TERM` is not `dumb`, `letsdo
<name>` starts a full-screen interface instead of the line stream:

```
letsdo · developer (@developer)            session 00:12:34
done 3 · left 2 · task TASK-42 · 00:03:21
├──────────────────────────────────────────────────────────┤
…scrollable combined log: agent text, tool lines and loop
 service messages in arrival order, newest at the bottom…
↑/↓ PgUp/PgDn scroll · p pause · r refresh · q quit   (p resume while paused)
```

- **Header** — agent identity (`letsdo · <name> (@handle)`) and the session
  timer (monotonic, ticks every second).
- **State line** — tasks done in this session, tasks left (from the latest
  backlog query), and either the running task with its elapsed time, a
  waiting reason (`no open tasks (retry in 10s)` / `backlog unavailable
  (retry in 10s)`), or `PAUSED` while the agent is suspended.
- **Stream** — one combined log of everything the agent produces: answer
  text deltas, tool lines and loop messages, exactly as OutputStreamer
  emits them. The view follows the newest line automatically (tail -f).
  While paused the frame freezes but the log keeps buffering, so nothing
  is lost.
- **Footer** — the key map; the `p` hint says `p pause` while the agent
  runs and `p resume` while it is suspended.

Keys:

| Key | Action |
| --- | --- |
| `↑` / `↓` | scroll one line (scrolling up leaves auto-follow) |
| `PgUp` / `PgDn` | scroll one page |
| `Home` / `End` | jump to top / back to the newest line (auto-follow) |
| `p` | pause/resume the agent: mid-run the running pi is suspended at the kernel level (SIGSTOP — model generation and tool executions freeze, the frame shows `PAUSED`, the log keeps buffering); between runs the next task is held until resume. A second `p` resumes (SIGCONT). The footer flips between `p pause` and `p resume` |
| `r` | immediate backlog re-query (updates the "left" counter) |
| `q` | quit — identical to a stop signal: the pi child is terminated, the terminal is restored, exit code 0 |
| `Ctrl+C` | same as `q` inside the TUI |

Resizes (`SIGWINCH`) repaint the frame without corruption. Every exit path —
quit, signal, agent loop end — restores the terminal (alternate screen
left, cursor back). Inside tmux the window is labeled with the agent name
for the whole session, so side-by-side agent panes stay distinguishable;
the previous label (and automatic-rename) returns on exit. The TUI only
renders when it is safe to do so; in any
other context the output is byte-identical to the plain line stream, which
is what keeps CI and pipes deterministic.

## How the loop behaves

`letsdo <name>` runs an orchestrator loop:

1. **Query** — fetch all open tasks assigned to `<name>` via the backlog
   CLI (the assignee comes from `AGENT_ASSIGNEE_HANDLE`, default `<name>`
   — the canonical bare name; `@<name>` is prose notation only).
2. **Run** — take the next task and run the agent on it. **One run = one
   task**; the agent must not pick up more than one task per run.
3. **Repeat** — when a run finishes, query again.
4. **Wait** — when no tasks are open (or the backlog is unreadable), wait
   the retry interval (10 s by default, see `LETSDO_WAIT_SECONDS`) and
   query again. An unreadable backlog pauses instead of crashing.
5. **Stop** — `Ctrl+C` / `SIGTERM` / `SIGHUP` (or `q` in the TUI, and on a
   terminal stdin in plain mode) stops the
   loop immediately: the running pi child is terminated (even when it was
   paused — SIGCONT comes before SIGTERM), the terminal is restored, exit
   code 0.

The waiting is interruptible — a stop signal unwinds the loop right away
instead of waiting out the retry interval. A non-zero agent exit code is
reported but does not stop the loop.

Pause (`p` in the TUI or in plain mode on a terminal stdin) between runs
sets a gate the loop polls before starting the next run: while paused, no
new task is started even when the backlog has open ones; resume lets the
queued task run.

## Running several agents

Agents run as separate processes, each with its own loop and its own
assignee:

```sh
letsdo developer &   # works on developer tasks
letsdo analyst   &   # works on analyst tasks
```

They coordinate through the shared backlog — nothing else in common. Any
number of agents can run simultaneously; the backlog folder is the single
source of truth.

When the agents run in tmux panes, a TUI session labels its window with the
agent name (`letsdo developer` → window `developer`) and restores the
previous label on exit. tmux's automatic-rename is disabled for the session
and restored afterwards, so the label stays put instead of being overwritten
with the process name (`ruby`). Outside tmux nothing is written and the tmux
binary is never invoked.

## Environment self-check (doctor)

`letsdo doctor` checks whether the environment can actually run the loop
and prints one line per check with a status tag and an actionable hint:

```
$ letsdo doctor
[ OK ] ruby 4.0.2 (>= 3.3)
[ OK ] pi command found: pi
[ OK ] backlog command found: backlog
[ OK ] project root /home/user/backlog-project has backlog/tasks/
[ OK ] AGENTS.md present at /home/user/backlog-project/AGENTS.md
[ OK ] agents/ present with 1 prompt(s)
[INFO] stdout is not a TTY - plain mode
```

Checks: Ruby version (`>= 3.3`), the `pi` command (`LETSDO_PI_COMMAND`),
the `backlog` command (`LETSDO_BACKLOG_COMMAND`), `backlog/tasks/` under
`LETSDO_ROOT`, `AGENTS.md`, a non-empty `agents/`, and whether stdout is a
TTY (TUI vs plain mode). A missing command or project layout is a `[FAIL]`;
a missing `AGENTS.md` or `agents/` is a `[WARN]`; the mode line is
`[INFO]`. Every FAIL and WARN names the fix.

It exits `0` when no check FAILs (warnings do not fail the run) and `1`
otherwise. `doctor` is a reserved agent name: it always runs the self-check
and never launches an agent.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | `--version` / `--help`; successful loop run and stop (incl. TUI `q`); `--init` created the prompt; `doctor` found no FAIL |
| `1` | no arguments; unknown option; `--init` on an existing/unsafe name; `doctor` found at least one FAIL |
| `2` | the AI backend command is missing (clean message, no backtrace) |

## Next steps

- [Prompt-authoring guide](prompts.md) — what to put into `agents/<name>.md`.
- [Configuration reference](config.md) — every environment variable, its
  default and where it is read.
- The README — why letsdo exists and what it does.