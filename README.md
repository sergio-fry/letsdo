# letsdo

> A local agent worker for Backlog.md/markdown tasks.

Letsdo turns a plain markdown backlog into a team of autonomous agents.
Each agent is just a prompt file in `agents/`; run `letsdo <name>` and the
agent picks up all open tasks assigned to it, one task per run, loops back
for new ones, and stops cleanly on `Ctrl+C`. No framework code, no hosted
platform — the backlog folder is the single source of truth.

[![CI](https://github.com/sergio-fry/letsdo/actions/workflows/ci.yml/badge.svg)](https://github.com/sergio-fry/letsdo/actions)

## Table of contents

- [Why letsdo](#why-letsdo)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Getting started](#getting-started)
- [Configuration](#configuration)
- [How it works](#how-it-works)
- [Guides](#guides)
- [Development](#development)
- [Alternatives](#alternatives)
- [Contributing](#contributing)
- [License](#license)

## Why letsdo

- **Your backlog already exists.** If you track work in a
  Backlog.md/markdown project (a `backlog/` folder of markdown tasks), you
  already have everything letsdo needs. The tasks are the instructions;
  letsdo only executes them.
- **Zero-config team.** A new agent is a new file: `agents/<name>.md`
  with the agent's instructions. The assignee handle is derived from the
  name (`@developer` ↔ `developer`), so the agent automatically works on
  the tasks already assigned to it. No code, no schemas, no setup.
- **One task per run — honest work.** Each run picks up exactly one open
  task and completes it before the next. No context-switching, no runaway
  loops: the orchestrator loop assigns the next task only after the current
  one finishes, and pauses when there is nothing to do.
- **Local and private.** Everything runs on your machine — `pi` in
  `--mode json` under the hood. No hosted agents, no task data leaving
  your project.
- **Observable.** The stream shows exactly what the agent is doing:
  agent text on stdout, tool calls with `HH:MM:SS` timestamps and
  completion durations on stderr.

Use it when you want a local, convention-driven worker that executes
backlog tasks autonomously: development chores, analysis spikes, doc
generation, any repeatable task flow you can express as assignee + prompt.

## Features

- **One-command agent run** — `letsdo <name>` starts the loop: all open
  tasks assigned to `@<name>` are done one after another (one agent run =
  one task), then the loop waits for new ones until stopped with
  `SIGINT/SIGTERM` (clean exit, code 0).
- **Agents as prompt files** — `agents/<name>.md` is the whole identity of
  an agent: role, rules, workflow. Add a file, get an agent. letsdo injects
  the agent's name and backlog assignee handle into the prompt on every
  launch, so the template only needs role and rules.
- **Built-in default prompt** — an agent starts even without a prompt file:
  it runs on the built-in default prompt (process-only instructions), and
  letsdo announces once where the prompt was looked for and how to create
  it (`letsdo <name> --init`).
- **`--init` scaffold** — `letsdo <name> --init` creates
  `agents/<name>.md` with the starter default prompt so you can customize
  it. It never runs the agent and never overwrites an existing file.
- **Orchestrator loop** — retries every 10 s (configurable) when there are
  no open tasks, pauses when the backlog is unreadable instead of crashing,
  and stops instantly on `Ctrl+C`.
- **Streaming output** — agent text streams to stdout as it is generated;
  service and tool lines go to stderr with a shared `HH:MM:SS` prefix:
  tool start (`⚙ name: args`) and completion with duration
  (`✓/✖ name: done/error (3s)`). Tool result bodies are not printed, so
  the stream stays readable while the agent works.
- **`--version` / `--help`** — `Letsdo::VERSION` and usage, exit 0.
- **Available as a library** — `require "letsdo"` exposes the
  `Letsdo` module (`Letsdo::VERSION`, `Letsdo::PromptStore`, `Letsdo::Agent`,
  ...) for embedding or testing.

## Requirements

- Ruby **>= 3.3**.
- The [pi](https://github.com/earendil-works/pi) agent CLI on
  `PATH` — this is the AI backend that runs the agent (`pi --mode json`).
  The command is configurable via `LETSDO_PI_COMMAND`.
- The Backlog.md CLI (`backlog`) on `PATH` — the task provider reads open
  tasks via `backlog task list --assignee <handle>`. Configurable via
  `LETSDO_BACKLOG_COMMAND`.

Tests and the build use only Ruby's bundled default gems (Minitest, Rake) —
no `bundle install` needed.

## Installation

The gem is built from the repository:

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

or run it straight from the checkout without installing:

```sh
cd letsdo
./bin/letsdo --version
```

## Getting started

Letsdo works in a Backlog.md project root — a folder that holds the
`backlog/` tasks and your `agents/` prompts:

```sh
cd your-backlog-project

# create an agent prompt (once)
letsdo developer --init        # writes agents/developer.md, never runs the agent

# or write agents/developer.md by hand — the file is the agent's instructions

# run the agent: it works through all open tasks assigned to @developer
letsdo developer
```

The loop prints service messages on stderr (started, which task is being
run, no open tasks / backlog unavailable, stopped) and streams the agent's
text on stdout. Stop the loop with `Ctrl+C` — a running agent child is
terminated and the process exits with code 0.

No prompt file? No problem:

```
$ letsdo newcomer
letsdo: no prompt for newcomer at /home/user/backlog-project/agents/newcomer.md
letsdo: using the built-in default prompt (create a prompt file with 'letsdo newcomer --init')
```

The agent still runs — on the built-in default prompt. The notification is
printed once per process. The looked-up path is exactly
`<LETSDO_ROOT>/agents/<name>.md`.

For the full walkthrough — install, session anatomy (plain and TUI), the
loop/waiting model, exit codes — see the [usage guide](docs/usage.md).

CLI reference:

```
letsdo <name>              # run the <name> agent in the loop (exit 0 on stop)
letsdo <name> --init       # create agents/<name>.md, never run the agent (exit 0)
letsdo --init <name>       # same as above (flag-first form)
letsdo --version           # gemspec version, exit 0
letsdo --help              # usage and agent list, exit 0
letsdo                     # usage and agent list, exit 1
letsdo --badopt            # "unknown option" + usage, exit 1
```

`--init` fails with exit 1 and a message on stderr when the file already
exists (never overwrites) or the agent name is unsafe (contains `/` or `\`,
or is `.`/`..` — nothing is ever written outside `agents/`).

## Configuration

All knobs are environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `LETSDO_ROOT` | current folder | Project root where `agents/` lives (and where the `backlog` CLI finds `backlog/`). |
| `LETSDO_PI_FLAGS` | — | Extra pi flags, e.g. `--model anthropic/claude-sonnet-4-5` (split on whitespace). |
| `AGENT_PI_FLAGS` | — | Fallback for `LETSDO_PI_FLAGS` (compatibility with the old `bin/agent`). |
| `LETSDO_PI_COMMAND` | `pi` | The pi command used to run agents; overridable for tests / fake pi. |
| `AGENT_ASSIGNEE_HANDLE` | `@<name>` | The agent's backlog assignee handle. The one rule: handle = name. Also the handle injected into the agent's prompt identity. |
| `LETSDO_WAIT_SECONDS` | 10 | Retry interval when there are no open tasks. |
| `AGENT_WAIT_SECONDS` | — | Fallback for `LETSDO_WAIT_SECONDS` (`bin/agent-loop` compatibility). |
| `LETSDO_MAX_RETRIES` | 3 | Max consecutive failed runs of the same task before giving up for the session. |
| `LETSDO_RETRY_BASE` | = `LETSDO_WAIT_SECONDS` | Base backoff seconds; doubles per failure, capped by `LETSDO_RETRY_CAP`. |
| `LETSDO_RETRY_CAP` | 300 | Maximum backoff seconds between attempts. |
| `LETSDO_BACKLOG_COMMAND` | `backlog` | The Backlog.md CLI command used as the task provider. |
| `LETSDO_PROVIDER` | `backlog` | Task provider name used by the loop (currently only `backlog`). |
| `LETSDO_BACKEND` | `pi` | AI backend that runs each agent (only `pi` today; `LETSDO_PI_COMMAND`/`LETSDO_PI_FLAGS` keep working as before). |
| `LETSDO_METRICS_FILE` | — | Append session metrics as JSON Lines (`session_start`, one `run_finished` per task, `session_stop`) to this path. Unset disables the file. |
| `LETSDO_TASK_TIME_COMMENT` | unset (off) | Set to `1` to append a `letsdo: completed in <time>` comment to each completed task's backlog record at stop (see the stop summary below). Off by default: no task file is modified and no extra backlog subprocess runs. |
| `LETSDO_DEBUG` | — | Set to `1` to trace loop decisions on stderr. |

On stop, letsdo prints a session summary to stderr — done / failed /
interrupted counts, open tasks left, total session time, time inside runs,
the derived waiting time, the average done-run duration, and up to ten
per-task lines (`TASK-42 done in 2m 10s`):

```
letsdo: session: 3 done, 1 failed, 0 interrupted, 4 left open, 12m 30s (8m 10s in runs, 4m 20s waiting, avg 2m 43s)
letsdo:   TASK-12 done in 3m 5s
letsdo:   TASK-13 failed in 1m 2s
```

The same summary prints in TUI mode after the terminal is restored, so a
TUI session leaves the identical record on stderr. With
`LETSDO_METRICS_FILE` set, the recorder also appends one JSON object per
event — `session_start`, `run_finished` (`{task, exit, outcome,
 elapsed_s, ts}`) and `session_stop` — flushing each line as it is written.
An unwritable path only warns on stderr; the run continues without the
file. `waiting` is a derived approximation (session time minus run time):
it also covers polling and backlog reads, not only idle waiting.

### Per-task elapsed in the task record (opt-in)

With `LETSDO_TASK_TIME_COMMENT=1`, letsdo writes the elapsed time back into
the task record at stop. The write-back is batched after every agent run
has ended (so it cannot race the agent's own closing edit), re-queries the
provider once, and comments only exit-0 runs whose task is **no longer
open** — a task still open after its run is skipped, because calling it
completed would be wrong. The comment is authored as `@letsdo`:

```
letsdo: completed in 4m 12s
```

It runs the configured `LETSDO_BACKLOG_COMMAND` in the project root
(`backlog task edit <id> --comment '...' --comment-author @letsdo`). A
missing or renamed task, or a failing command, warns once per task
(`letsdo: cannot write task time comment for TASK-12: ...`) and the summary
reports `N comments not written`; the stop path and the exit code are
unaffected. The flag is off by default, so a normal session never touches
task files and never spawns an extra backlog process.

The comprehensive reference — every variable with defaults, precedences,
examples and where each one is read — lives in the
[configuration reference](docs/config.md).

## Failure handling

When an agent run fails, the loop avoids hammering the same task and
instead backs off, then gives up for the session:

- **Non-zero exit** (including a task killed by a signal, exit 128+):
  counts as a failure of that task.
- **Exit 0 but the task is still open** on the next provider poll:
  also counts as a failure — the agent ended without closing the task.
- **Task gone from the provider** after a run: counts as success and
  clears the task's retry state.

Failing tasks are retried with exponential backoff: after the *n*
failure the task is skipped from the attempt batches until
`now >= now + min(LETSDO_RETRY_BASE * 2^(n-1), LETSDO_RETRY_CAP)`
seconds have elapsed (default: 10s, 20s, 40s, capped at 300s).

After `LETSDO_MAX_RETRIES` (default 3) consecutive failures the loop
stops attempting that task for the rest of the session, logs
`letsdo: giving up on <TASK> after N failed runs — task stays open,
next session will retry it` to stderr, and keeps processing other
open tasks. A fresh `letsdo` session starts with no failure state,
so a temporarily-failing task is retried next session.

**Backend missing**: when the AI backend binary cannot be started
(`LETSDO_PI_COMMAND` points at a nonexistent or non-executable file),
letsdo prints a clear message and exits with code 2 — no Ruby
backtrace.

The loop's stop semantics are unchanged: `SIGINT`/`SIGTERM` during a
backoff cooldown exits promptly with code 0, and a started run is
always terminated (TERM then KILL after a grace period) and reaped.

## How it works

```
bin/letsdo ──► Letsdo::CLI ──► Letsdo::Agent ──► Letsdo::PiRunner (pi --mode json)
                     │                │                    │
                     │                │              Letsdo::OutputStreamer (stdout/stderr)
                     ▼                ▼
             Letsdo::BacklogTasks  Letsdo::AgentLoop
             (backlog CLI → tasks) (orchestrator loop)
```

- `Letsdo::CLI` — argument parsing, usage, exit codes; builds the agent, the
  task provider and the loop.
- `Letsdo::PromptStore` — access to `agents/<name>.md` prompts; `--init`
  writes them via `create_agent` (no overwrite, safe names only).
- `Letsdo::DefaultPrompt` — the built-in default prompt: the single source
  of truth used both for the fallback run and as the `--init` template.
- `Letsdo::Agent` — one agent run: the prompt (file or default) + a `pi`
  child process; returns the pi exit code.
- `Letsdo::PiRunner` — spawns `pi --mode json <flags> <prompt>`, parses the
  line-by-line event stream, feeds the streamer, propagates the pi exit
  code (including 128+signal).
- `Letsdo::OutputStreamer` — routes agent text to stdout and service/tool
  lines to stderr with `HH:MM:SS` prefixes and durations.
- `Letsdo::BacklogTasks` — the task provider: open tasks for a handle via
  `backlog task list --assignee <handle> --exclude-status Done --json`;
  `nil` when the backlog is unreadable (the loop pauses instead of running
  the agent).
- `Letsdo::Loop` / `Letsdo::AgentLoop` — the orchestrator: tasks → one run
  each → wait → repeat; stopped from outside via `SIGINT/SIGTERM` (the
  running pi child is terminated, exit 0).

Multiple agents run as separate processes, each with its own loop and its
own assignee; they coordinate through the shared backlog — nothing else in
common. This repository itself is run by letsdo: `agents/developer.md` and
`agents/analyst.md` are its own workers on the `backlog/` tasks.

## Guides

- [Usage guide](docs/usage.md) — install, first run, loop semantics,
  the interactive TUI and its keys, exit codes.
- [Prompt-authoring guide](docs/prompts.md) — what makes a good agent
  prompt: must-haves, anti-patterns, worked examples.
- [Configuration reference](docs/config.md) — every environment variable,
  its default, precedence and where it is read.

## Development

The gem uses Minitest (bundled with Ruby, plain `assert`/`refute`, no
external DSLs or mock frameworks), so tests run on a clean Ruby:

```sh
rake test                                  # all tests
ruby -Itest -Ilib test/cli_test.rb         # one test file
```

Test fixtures: `test/fixtures/fake_pi` emulates the `pi --mode json` event
stream (`FAKE_PI_SCENARIO=default|error|big|stub`); the CLI snapshots the
spawned fake-pi argv per run, which tests assert on.

Building the gem:

```sh
gem build letsdo.gemspec
```

Cleanliness is enforced by the CI workflow
(`.github/workflows/ci.yml`): gem build + `rake test` on every push,
Ruby 3.3 and 4.0 (satisfies `required_ruby_version: ">= 3.3"`).

## Alternatives

| Tool | What it is | What's similar | What's different |
| --- | --- | --- | --- |
| [Claude Code](https://github.com/anthropics/claude-code) | Anthropic's terminal agent | Local, terminal-driven, works in your repository | Interactive chat sessions you drive; no backlog loop, no one-task-per-run contract, no multi-agent-by-convention |
| [OpenAI Codex CLI](https://github.com/openai/codex) | OpenAI's terminal coding agent | Local agent on the command line | Same interactive pattern; session-based, not a task-execution worker |
| [CrewAI](https://github.com/crewAIInc/crewAI) / [AutoGPT](https://github.com/Significant-Gravitas/AutoGPT) | Agent orchestration frameworks (Python) | Multi-agent teams and roles | The team, tools and workflow are code and configuration; no built-in task-tracker loop |
| [aider](https://github.com/Aider-AI/aider) | Pair-programming CLI | Local AI pair for code changes | Focused on interactive coding pairs, not executing a tracked backlog |

What none of them do out of the box: take an existing markdown backlog,
derive the team from the assignee handles, and execute the tasks one per
run with an observable loop. That is letsdo's niche — a thin convention
layer instead of a framework. If your project is tracked in Backlog.md
format and you want a local, observable, multi-agent worker on top of it,
letsdo is the smallest thing that does it.

## Contributing

Contributions are welcome. The project is small and intentionally so —
please keep it that way.

- **Language.** All task tracking, prompts, docs and comments are in
  English (project convention). New code and docs follow suit.
- **Where the code lives.** `bin/letsdo` (entry point),
  `lib/letsdo/` (CLI, PromptStore, DefaultPrompt, Agent, PiRunner,
  OutputStreamer, BacklogTasks, Loop, AgentLoop), `test/` (Minitest +
  fixtures), `letsdo.gemspec`, `.github/workflows/ci.yml`.
- **Before opening a PR:** `rake test` must pass with 0 failures and the
  gem must build (`gem build letsdo.gemspec`) — the same checks CI runs on
  every push.
- **Dogfooding.** This repository manages itself with letsdo: new work is
tracked as Backlog tasks, and `agents/developer.md` / `agents/analyst.md`
execute them. Every change is a chance to exercise the tool.

## License

MIT — see [LICENSE](LICENSE).