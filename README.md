# letsdo

A local agent worker for Backlog.md/markdown tasks.

A Ruby gem: the `lib/letsdo` library (OOP structure: agents, the `agents/`
prompt store, the pi output streamer, error handling, the orchestrator loop)
and the executable `bin/letsdo`. In the future the gem moves to its own
repository — for now it lives in the `letsdo/` folder at the project root.

## Usage

From the `letsdo/` folder:

```sh
./bin/letsdo <name>    # read agents/<name>.md and run pi (exit = pi code)
./bin/letsdo --version # gem version (from lib/letsdo/version.rb), exit 0
./bin/letsdo --help    # help, exit 0
./bin/letsdo           # usage and agent list, exit 1
```

The project root (where `agents/` lives) is `LETSDO_ROOT`, default is the
current folder. Extra pi flags — `LETSDO_PI_FLAGS` (or `AGENT_PI_FLAGS` for
`bin/agent` compatibility), pi command — `LETSDO_PI_COMMAND` (default `pi`,
overridden in tests).

As a library:

```ruby
require "letsdo"        # module Letsdo, Letsdo::VERSION
```

## Code structure

Gem OOP structure:

```
letsdo/
  bin/letsdo            # entry point: thin wrapper over Letsdo::CLI
  lib/letsdo.rb         # module Letsdo, requires all components
  lib/letsdo/errors.rb # Letsdo::Errors: error hierarchy
  lib/letsdo/prompt_store.rb  # Letsdo::PromptStore: agents/*.md prompts
  lib/letsdo/output_streamer.rb # Letsdo::OutputStreamer: where output is printed
  lib/letsdo/pi_runner.rb     # Letsdo::PiRunner: running pi --mode json
  lib/letsdo/agent.rb         # Letsdo::Agent: a single agent run
  lib/letsdo/loop.rb          # Letsdo::Loop: orchestrator loop
  lib/letsdo/cli.rb           # Letsdo::CLI: arguments, usage, exit code
  test/                 # Minitest tests (test/*_test.rb, fixtures/fake_pi)
  letsdo.gemspec        # name=letsdo, executables=["bin/letsdo"]
  Gemfile               # gemspec
  Rakefile              # rake test
  README.md
  LICENSE               # MIT
```

Class responsibilities:

- **Letsdo::Errors** — the package error hierarchy: `Letsdo::Error` (base),
  `Letsdo::UnknownAgentError` (an agent is not in `agents/`, carries `.name`).
- **Letsdo::PromptStore** — access to `agents/<name>.md` prompts in the
  project root: `list` (sorted names), `read(name)` (contents or
  `UnknownAgentError`). A new agent = a new file, no code changes needed.
- **Letsdo::OutputStreamer** — routes pi output across two streams: the
  answer text (text_delta) — to stdout, service tool lines — to stderr.
  Every action line gets a shared `HH:MM:SS` time prefix (start
  `⚙ name: arguments`, completion `✓/✖ name: … (Xs)`), the result is an
  indented block, big output is trimmed with a summary note, error results
  are marked (`✖ Error: ...`); `finish` guarantees a final newline. The
  action duration is visible from the difference between the start and
  completion time prefixes.
- **Letsdo::PiRunner** — runs `pi --mode json <flags> <prompt>`, reads the
  line-by-line event stream, hands the streamer `text_delta` (agent text),
  tool headers and results (`tool_execution_start`/`_end`), ignores non-JSON
  and unrelated events, propagates the pi exit code (including 128+signal).
  The pi command is overridable (`command:`) — for tests.
- **Letsdo::Agent** — a single agent run: reads the prompt from `agents/`
  via `PromptStore` and runs `PiRunner`. Returns the pi exit code; for an
  unknown name raises `UnknownAgentError`. This is the logic of a single
  run of the old `bin/agent`, moved into the gem.
- **Letsdo::Loop** — the orchestrator loop: while the provider gives open
  tasks — runs the agent (one run = one task); no tasks — waits and checks
  again; `nil` from the provider = the backlog is unreadable, the agent is
  not run. Stopping — only from outside via `#stop` (e.g. by a
  SIGINT/SIGTERM handler, as in `bin/agent-loop`). The provider and the
  runner are injected — this way the loop is testable without a real
  backlog and pi.
- **Letsdo::CLI** — argument parsing and launching: usage and agent list
  with no argument (exit 1), `--version`/`--help` (exit 0), unknown option
  (exit 1), unknown agent — message + list (exit 1); known agent — a run
  through `Letsdo::Agent`, pi exit code.

## Development

Tests use Minitest bundled with Ruby (the simple `assert`/`refute` syntax,
no external DSLs or mock frameworks). Covered: `agents/` prompt reading,
known/unknown agent, output assembly from `text_delta`, tool headers and
results (including errors and big-output trimming), `HH:MM:SS` time prefixes
on action lines, exit-code propagation, the orchestrator loop, CLI. The fake
pi — `test/fixtures/fake_pi` — emulates the `pi --mode json` event stream for
deterministic tests (scenarios `FAKE_PI_SCENARIO=default|error|big|stub`).

Running tests without external gems:

```sh
rake test                 # all tests
ruby -Itest -Ilib test/prompt_store_test.rb   # one file
```

Building the gem:

```sh
gem build letsdo.gemspec
```

## License

MIT — see [LICENSE](LICENSE).