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
- [Exit codes](#exit-codes)
- [Next steps](#next-steps)

## Prerequisites

- **Ruby >= 3.0**.
- The **pi agent CLI** on `PATH` — the AI backend that actually runs each
  agent (`pi --mode json`). Override the command with `LETSDO_PI_COMMAND`
  (see the [configuration reference](config.md)).
- The **Backlog.md CLI** (`backlog`) on `PATH` — the task provider reads the
  open tasks assigned to an agent via
  `backlog task list --assignee <handle>`. Override with
  `LETSDO_BACKLOG_COMMAND`.

Tests and the gem build use only Ruby's bundled default gems (Minitest,
Rake) — no `bundle install` needed.

## Install

Build and install the gem from the repository:

```sh
git clone git@github.com:sergio-fry/letsdo.git
cd letsdo
gem build letsdo.gemspec
gem install letsdo-0.1.0.gem
```

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

# Run the agent: it works through all open tasks assigned to @developer
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
    indented lines                    tool result, no time prefix (data, not actions)
    … [output truncated: N lines, M]  big results are trimmed with a summary note
  HH:MM:SS ✓ tool_name: done (3s)     tool completion, success
  HH:MM:SS ✖ tool_name: error (3s)    tool completion, error
  ✖ Error: ...                        error result marked explicitly
  ```

- Loop service messages on stderr, e.g.:

  ```
  letsdo: developer has 3 open task(s)
  letsdo: running developer for TASK-42
  letsdo: no open tasks for developer, retrying in 10s
  letsdo: backlog unavailable, retrying in 10s
  letsdo: stopped
  ```

Stop the loop with `Ctrl+C` (`SIGINT`; `SIGTERM` and `SIGHUP` — terminal
closed — work too) — a running pi child is terminated and the process
exits with code 0. With `LETSDO_DEBUG=1` the loop additionally traces
`[letsdo] loop: ...` decisions to stderr.

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
left, cursor back). The TUI only renders when it is safe to do so; in any
other context the output is byte-identical to the plain line stream, which
is what keeps CI and pipes deterministic.

## How the loop behaves

`letsdo <name>` runs an orchestrator loop:

1. **Query** — fetch all open tasks assigned to `@<name>` via the backlog
   CLI (the assignee handle comes from `AGENT_ASSIGNEE_HANDLE`, default
   `@<name>`).
2. **Run** — take the next task and run the agent on it. **One run = one
   task**; the agent must not pick up more than one task per run.
3. **Repeat** — when a run finishes, query again.
4. **Wait** — when no tasks are open (or the backlog is unreadable), wait
   the retry interval (10 s by default, see `LETSDO_WAIT_SECONDS`) and
   query again. An unreadable backlog pauses instead of crashing.
5. **Stop** — `Ctrl+C` / `SIGTERM` / `SIGHUP` (or `q` in the TUI) stops the
   loop immediately: the running pi child is terminated (even when it was
   paused — SIGCONT comes before SIGTERM), the terminal is restored, exit
   code 0.

The waiting is interruptible — a stop signal unwinds the loop right away
instead of waiting out the retry interval. A non-zero agent exit code is
reported but does not stop the loop.

Pause (`p` in the TUI) between runs sets a gate the loop polls before
starting the next run: while paused, no new task is started even when the
backlog has open ones; resume lets the queued task run.

## Running several agents

Agents run as separate processes, each with its own loop and its own
assignee handle:

```sh
letsdo developer &   # works on @developer tasks
letsdo analyst   &   # works on @analyst tasks
```

They coordinate through the shared backlog — nothing else in common. Any
number of agents can run simultaneously; the backlog folder is the single
source of truth.

## Exit codes

| Code | Meaning |
| --- | --- |
| `0` | `--version` / `--help`; successful loop run and stop (incl. TUI `q`); `--init` created the prompt |
| `1` | no arguments; unknown option; unknown agent name; `--init` on an existing/unsafe name |

## Next steps

- [Prompt-authoring guide](prompts.md) — what to put into `agents/<name>.md`.
- [Configuration reference](config.md) — every environment variable, its
  default and where it is read.
- The README — why letsdo exists and what it does.