# letsdo — configuration reference

Configuration comes from two places: environment variables (everything in
this reference) and an optional YAML front-matter block at the top of an
agent's prompt file, `agents/<name>.md` — see
[Per-agent configuration](#per-agent-configuration-yaml-front-matter).
Nothing else is configured in files.

## Project layout

```
LETSDO_ROOT  (default: the current working directory)
├── backlog/            # the Backlog.md tasks — the task provider reads them
├── agents/<name>.md    # one prompt file per agent
└── bin/letsdo          # the executable (or the installed letsdo command)
```

- `LETSDO_ROOT` — project root: `agents/` lives there, and the `backlog`
  CLI resolves `backlog/` there. Default: the folder letsdo was started
  from.
- The agent's assignee handle is `@<name>` by default — the agent works on
  tasks assigned to that handle.

## Environment variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `LETSDO_ROOT` | current directory | Project root where `agents/` lives (and where the `backlog` CLI finds `backlog/`). |
| `LETSDO_PI_FLAGS` | unset (no flags) | Extra pi flags, split on whitespace, e.g. `--model anthropic/claude-sonnet-4-5`. A `--model` here overrides the agent's front-matter `model:` (see [Per-agent configuration](#per-agent-configuration-yaml-front-matter)). |
| `AGENT_PI_FLAGS` | unset | Fallback for `LETSDO_PI_FLAGS` when it is blank (compatibility with the old `bin/agent`). |
| `LETSDO_PI_COMMAND` | `pi` | The pi command used to run agents; overridable for tests / fake pi. |
| `AGENT_ASSIGNEE_HANDLE` | `@<name>` | The agent's backlog assignee handle (used verbatim when set). Also injected as the agent's identity in its prompt. |
| `LETSDO_WAIT_SECONDS` | `10` | Retry interval (seconds) when there are no open tasks. |
| `AGENT_WAIT_SECONDS` | `10` (via fallback) | Fallback for `LETSDO_WAIT_SECONDS` when it is blank (`bin/agent-loop` compatibility). |
| `LETSDO_MAX_RETRIES` | `3` | Max consecutive failed runs of the same task before giving up for the session. |
| `LETSDO_RETRY_BASE` | = `LETSDO_WAIT_SECONDS` | Base backoff seconds; doubles per failure, capped by `LETSDO_RETRY_CAP`. |
| `LETSDO_RETRY_CAP` | `300` | Maximum backoff seconds between attempts. |
| `LETSDO_BACKLOG_COMMAND` | `backlog` | The Backlog.md CLI command used as the task provider. |
| `LETSDO_PROVIDER` | `backlog` | Task provider name used by the loop (currently only `backlog`). |
| `LETSDO_BACKEND` | `pi` | AI backend that runs each agent (only `pi` today; `LETSDO_PI_COMMAND`/`LETSDO_PI_FLAGS` keep working as before). |
| `LETSDO_DEBUG` | unset | Set to `1` to trace loop and runner decisions (`[letsdo] loop: ...`) on stderr. |
| `LETSDO_TASK_TIME_COMMENT` | unset (off) | Set to `1` to append a `letsdo: completed in <time>` comment to each completed task's backlog record at session stop. Off by default: no task file is modified and no extra backlog subprocess runs. |

### Precedence rules

- `LETSDO_PI_FLAGS` → `AGENT_PI_FLAGS`: the flags are read from
  `LETSDO_PI_FLAGS`; when it is blank/absent, `AGENT_PI_FLAGS` is used. A
  blank result means no flags.
- `LETSDO_WAIT_SECONDS` → `AGENT_WAIT_SECONDS`: same pattern, falling back
  to the default `10`. A non-numeric value also falls back to `10`.
- `LETSDO_RETRY_BASE` → `LETSDO_WAIT_SECONDS`: when
  `LETSDO_RETRY_BASE` is blank or non-numeric, the backoff base falls back
  to the effective `LETSDO_WAIT_SECONDS` value.
- `LETSDO_MAX_RETRIES`: an invalid (non-integer) value falls back to `3`.
- `LETSDO_RETRY_CAP`: an invalid (non-numeric) value falls back to `300`.
- `AGENT_ASSIGNEE_HANDLE`: used as-is when set and non-blank; otherwise the
  one rule: handle = `@<name>`. The resolved value is both the assignee the
  loop queries the backlog for and the handle letsdo injects into the
  agent's prompt identity.
- Agent `model` → `LETSDO_PI_FLAGS`/`AGENT_PI_FLAGS`: a `--model` in the
  flags wins; the agent's front-matter `model:` is used only when the flags
  carry no `--model`. See
  [Per-agent configuration](#per-agent-configuration-yaml-front-matter).

### Examples

```sh
# Point letsdo at a project from anywhere
export LETSDO_ROOT=/srv/projects/acme-backlog

# Choose the pi model
export LETSDO_PI_FLAGS="--model anthropic/claude-sonnet-4-5"

# Less chatty backlog polling
export LETSDO_WAIT_SECONDS=30
export LETSDO_DEBUG=1        # trace loop decisions when diagnosing

# Non-standard installations
export LETSDO_PI_COMMAND=/opt/pi/bin/pi
export LETSDO_BACKLOG_COMMAND=~/.local/bin/backlog
```

## Per-agent configuration (YAML front matter)

A prompt file may start with a YAML front-matter block that carries launch
settings for that one agent. The block is optional: a file without it
behaves exactly as before.

```markdown
---
model: anthropic/claude-sonnet-4-5
---

# Developer agent (developer)
You are a developer agent named developer.
...
```

Rules:

- The block must be the *very first* thing in `agents/<name>.md`: a `---`
  line, the YAML keys, a closing `---` line. The rest of the file stays the
  prompt.
- The front matter is stripped before the file is handed to the agent, so it
  never appears in the system prompt.
- `model` is the only key consumed today:
  - `model: <name>` is passed to pi as `--model <name>` for that agent.
  - Absent → no `--model` is added and pi uses its own default model.
  - A missing file, no front matter, or invalid YAML is treated the same as
    absent: the block is ignored and the run continues.
- Precedence: a `--model` coming from `LETSDO_PI_FLAGS`/`AGENT_PI_FLAGS`
  wins over the file's `model:`. If you set a global `--model`, every agent
  uses it and the front matter is ignored — leave `--model` out of the
  global flags to select the model per agent.
- The block is extensible: unknown keys (e.g. `tags:`) are parsed and
  ignored, so new parameters can be added later without breaking existing
  prompt files.

Read by `Letsdo::PromptStore#config` (`lib/letsdo/prompt_store.rb`), passed
to the backend by `Letsdo::Agent#run` (`lib/letsdo/agent.rb`) and applied in
`Letsdo::Backends::Pi#initialize` (`lib/letsdo/backends/pi.rb`).

## TERM and TUI selection

The interactive TUI is engaged only when **all** of these hold:

1. stdout is a TTY, and
2. stdin is a TTY, and
3. `TERM` is not `dumb`.

Otherwise letsdo prints the plain line-stream output — byte-identical to
the pre-TUI behavior, with no escape codes. Set `TERM=dumb` (or pipe stdout
through something) to force the plain mode explicitly, e.g. in scripts or
CI.

## Where each variable is read

- `LETSDO_ROOT` — `Letsdo::CLI#initialize` (`lib/letsdo/cli.rb`).
- `LETSDO_PI_FLAGS` / `AGENT_PI_FLAGS` — `Letsdo::CLI#parse_pi_flags`
  (`lib/letsdo/cli.rb`).
- `LETSDO_PI_COMMAND` — `Letsdo::CLI#pi_command` (`lib/letsdo/cli.rb`),
  default `PiRunner::COMMAND` (`lib/letsdo/pi_runner.rb`).
- `AGENT_ASSIGNEE_HANDLE` — `Letsdo::CLI#assignee_handle`
  (`lib/letsdo/cli.rb`).
- `LETSDO_WAIT_SECONDS` / `AGENT_WAIT_SECONDS` — `Letsdo::CLI#wait_seconds`
  (`lib/letsdo/cli.rb`).
- `LETSDO_BACKLOG_COMMAND` — `Letsdo::CLI#backlog_command`
  (`lib/letsdo/cli.rb`).
- `LETSDO_PROVIDER` — `Letsdo::Config#provider` and
  `Letsdo::CLI::Builder#resolve_provider!` (unknown values fail fast with
  `letsdo: unknown task provider: <name>`, exit code 1).
- `LETSDO_BACKEND` — `Letsdo::Config#backend` and
  `Letsdo::CLI::Builder#resolve_backend!` (unknown values fail fast with
  `letsdo: unknown AI backend: <name>`, exit code 1).
- `LETSDO_DEBUG` — `Letsdo::AgentLoop#initialize` (`lib/letsdo/agent_loop.rb`)
  and `Letsdo::PiRunner#initialize` (`lib/letsdo/pi_runner.rb`); enabled when
  the value is exactly `"1"`.
- `LETSDO_TASK_TIME_COMMENT` — `Letsdo::Config#task_time_comment?`
  (`lib/letsdo/config.rb`); enabled only when the value is exactly `"1"`.
  Consumed by `Letsdo::CLI::Builder#finish_session`, which runs
  `Letsdo::TaskTimeWriteback` at stop.
- `TERM` — `Letsdo::CLI#tui?` (`lib/letsdo/cli.rb`).

## External Requirements (not configurable)

- The **pi CLI** is a runtime requirement of letsdo — an external binary,
  not a rubygem dependency. `LETSDO_PI_COMMAND` only replaces the command
  name. See the [usage guide](usage.md) prerequisites.
- Test-only environment variables (`FAKE_PI_*`, `FAKE_BACKLOG_*`) belong to
  the test fixtures (`test/fixtures/`) and are not part of the runtime
  configuration.