---
id: TASK-52
title: >-
  Spike: AI backend adapter (pi today; Claude Code / Cursor as future backends)
  — decouple business logic
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 07:11'
updated_date: '2026-09-04 07:43'
labels: []
dependencies:
  - TASK-50
type: spike
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design the adapter seam between letsdo business logic and the AI/agent backend (per user request: instead of pi one day Cursor console / Claude could be used — business logic must not hard-depend on a single product).

Current state: Letsdo::Agent builds PiRunner directly — it hardcodes 'pi --mode json <flags> <prompt>', parses pi-specific events (message_update/text_delta, toolcall_start, tool_execution_start/end, agent_end), OutputStreamer consumes those events, termination goes through process-group kill (PiRunner#terminate). Env knobs today: LETSDO_PI_COMMAND, LETSDO_PI_FLAGS (=> backend-specific already leak into CLI).

Design goal: define a backend interface — run(prompt) or run(task) → normalized streaming events + exit code; terminate/stop support; backend selection (env knob e.g. LETSDO_BACKEND=pi|claude|cursor, default pi; overridable for tests); map the pi protocol onto normalized events so OutputStreamer/business layer stays backend-agnostic; keep LETSDO_DEBUG semantics. Roadmap for a real second backend (Claude Code / Cursor CLI) must be described as developer tasks, NOT implemented here.

Coordinate with TASK-50 (target layout) and TASK-52 (same interface philosophy for the task provider side). Deliverable: design documented in task comments + developer tasks (@developer) with ACs. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Normalized backend protocol specified: event types, exit-code semantics, termination/stop, debugging — independent of pi vocabulary
- [x] #2 How pi maps onto the protocol (PiRunner → pi_backend adapter, fake backend for tests replacing fake_pi approach evaluated)
- [x] #3 Backend registry/selection designed (env-driven default pi, injectable for tests); what stays in business logic vs adapter is explicit (Agent/Loop/OutputStreamer/CLI deltas)
- [x] #4 Adding a second real backend (Claude Code / Cursor) described as developer tasks with ACs — not implemented
- [x] #5 Spike leaves the code untouched (no commits, no file edits)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify current backend chain in code: Agent builds PiRunner directly; PiRunner mixes subprocess lifecycle + pi JSON parsing + formatting hooks; termination surface = Agent#runner (attr) -> PiRunner#terminate_now (trap-safe) / #terminate (grace+kill); env knobs LETSDO_PI_COMMAND/LETSDO_PI_FLAGS (CLI) and LETSDO_DEBUG (PiRunner/AgentLoop each); OutputStreamer API (text_delta/tool_start/tool_result/finish) is already the normalized stream surface. Test seams: fake_pi executable + FAKE_PI_* env, pi_runner_test/agent_test/cli_test inject command. 2. Design: Letsdo::Backends namespace (reserved by TASK-50), documented backend protocol (run -> exit code, streaming normalized events; terminate_now/terminate; debug; LETSDO_DEBUG semantics), backends/pi.rb = PiRunner move (one move, not twice), registry/selection LETSDO_BACKEND (default pi) in Letsdo::CLI::Builder, fake backend for tests; business layer deltas explicit (Agent takes backend_factory; AgentLoop agent.backend; Loop/OutputStreamer/TUI unchanged). Coordinate with TASK-50 layout, TASK-51 provider conventions (LETSDO_PROVIDER vs LETSDO_BACKEND), TASK-53 Config, TASK-54 Builder. 3. Record design as task comment. 4. Create developer tasks (@developer, ACs): (a) backends/pi.rb move + protocol; (b) LETSDO_BACKEND selection + registry + fake backend; (c) roadmap describing second real backend (Claude Code / Cursor), not implemented. 5. task-finalization: verify ACs with evidence, final summary, Done, commit backlog folder only (spike leaves code untouched).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: (1) Design comment present in the task file — grep confirms all six sections (CURRENT COUPLING, normalized backend protocol, PI MAPPING + fake-backend evaluation, REGISTRY/SELECTION with business-vs-adapter split, ROADMAP, SEQUENCING). (2) Developer tasks verified via --json: TASK-59 (Backends::Pi move + protocol, 6 ACs, dep TASK-42), TASK-60 (LETSDO_BACKEND registry in Letsdo::CLI::Builder, 6 ACs, deps TASK-42/53/54/59), TASK-61 (roadmap: second AI backend Claude Code first, 4 ACs, dep TASK-60) — all Status To Do, Assignee @developer, referenced from TASK-52, in English (TASK-35). (3) Code untouched: git status (raw porcelain) shows only backlog/tasks/task-52 (modified) + task-59/60/61 (new) from this spike; the other working-tree changes (gemspec, lib/*, test/*, tui files) pre-existed from in-flight TASK-42 and are NOT staged by this spike. (4) Sequencing: TASK-59 lands after TASK-42 (green baseline); TASK-60 after TASK-53/54 so Config owns LETSDO_BACKEND and Builder owns the registry (per TASK-50 Phase-1 promise); TASK-61 is a roadmap placeholder.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-04 07:41
---
Design: AI backend adapter seam (verified 2026-09-04, working tree incl. in-flight TASK-42)

CURRENT COUPLING (verified)
- Letsdo::Agent builds Letsdo::PiRunner directly: @runner = PiRunner.new(prompt:, flags:, streamer:, command:); run = prompt_store.read(name) + @runner.run -> exit code. attr_reader :runner is the termination surface.
- Terminal/stop chain: AgentLoop#on_signal -> @agent&.runner&.terminate_now (trap-safe one-shot SIGTERM to the pi process group, no waits/IO); PiRunner#run rescues Letsdo::Stopped, calls #terminate (grace TERM -> KILL), reaps, re-raises. TUI 'q'/Ctrl-C goes through the same Letsdo::Stopped unwind (tui/session.rb).
- PiRunner mixes 3 concerns: (a) subprocess lifecycle (spawn -pgroup, wait, exit codes 0/N/128+sig, terminate/terminate_now), (b) pi JSON event parsing (message_update/text_delta, toolcall_start, tool_execution_start/end, agent_end, pending-tools fallback), (c) formatting hooks via the streamer. The streamer API — text_delta / tool_start(name, args:) / tool_result(name, text, error:) / finish — is ALREADY the normalized stream surface (pi vocabulary never crosses it).
- Backend-specific env knobs leak into CLI: LETSDO_PI_COMMAND + LETSDO_PI_FLAGS (with AGENT_PI_FLAGS fallback) parsed in cli.rb and passed down; LETSDO_DEBUG read independently in PiRunner and AgentLoop (nil -> ENV check, two copies).
- Blast radius (grep): lib/letsdo.rb (docstring+require), agent.rb (builds PiRunner), cli.rb (env parse + Agent.new(command:)), agent_loop.rb (runner call in on_signal + comment), tui/session.rb (comments only), test/pi_runner_test.rb, test/agent_test.rb, test/cli_test.rb (fake_pi via LETSDO_PI_COMMAND), test/fixtures/fake_pi.

1. NORMALIZED BACKEND PROTOCOL (AC#1) — Letsdo::Backends
A backend = one agent run against one AI/CLI product. Protocol (documented, duck-typed; optional shared base Letsdo::Backends::Backend for process-spawning backends):
- #run -> Integer exit code. Spawns/starts the backend, reads its output, and streams NORMALIZED events to the injected streamer as they happen; returns the child exit code (0 = success, non-zero = run failed — business layer logs it and the loop continues, exactly as today; 128+signal documented for killed runs). Runs to completion; stop arrives as Letsdo::Stopped raised by the trap (keep the raise-in-trap / CRuby-4.0 notes in the pi adapter).
- #terminate_now — trap-safe one-shot stop: no waits/IO/sleeps (SIGTERM to the process group for CLI backends; no-op where impossible). Required so AgentLoop#on_signal keeps its shape.
- #terminate(signal: "TERM", grace: 3.0, tick: 0.05) — graceful stop then SIGKILL after grace; safe to call when the run already finished (no-op). Caller reaps the child afterwards (same contract as PiRunner#run).
- debug(message) — writes '[letsdo] <backend>: ...' to stderr when debug enabled; enabled via LETSDO_DEBUG (single read moved to Letsdo::Config per TASK-53; semantics unchanged: absent -> nil -> disabled).
Normalized event vocabulary emitted at the streamer (exactly OutputStreamer's method set — no rename churn, behavior identical):
  text_delta(delta)  — fragment of the agent's answer text;
  tool_start(name, args: nil) — a tool began (name + short args summary);
  tool_result(name, text, error: false) — tool finished (result text + error flag);
  finish — stream ended; called exactly once per run (guarantees the trailing newline).
pi vocabulary (message_update/text_delta, toolcall_start, tool_execution_start/end, agent_end) is FORBIDDEN outside the pi adapter. run(prompt) today; run(prompt, task:) is the documented growth path for per-task context (business layer owns PromptStore; the backend receives the prompt as data, never reads files).

2. PI MAPPING (AC#2) — Letsdo::Backends::Pi = PiRunner moved to lib/letsdo/backends/pi.rb (one move, per TASK-50 reservation; no double-move). Keeps byte-identical: 'pi --mode json <flags> <prompt>' spawn in its own process group, JSON line parsing, message_update/toolcall_start/tool_execution_start/end/agent_end mapping, pending-tools fallback, exit-code propagation, terminate/terminate_now semantics, debug prefix '[letsdo] pi:'. Constructed with prompt:, streamer:, pi command + flags (from Letsdo::Config per TASK-53 — pi-specific knobs no longer read by CLI/business layer), debug:. LETSDO_PI_COMMAND/LETSDO_PI_FLAGS/AGENT_PI_FLAGS continue to work exactly as today (tests keep passing unchanged).
TEST-SEAM EVALUATION (fake backend replacing fake_pi): keep BOTH, each for its layer.
- fake_pi executable + FAKE_PI_* env stays for the pi adapter's own tests (backends/pi_test.rb): only a process-based fake can exercise argv order, FAKE_PI_EXIT propagation, and process-group terminate/kill semantics. Existing pi_runner_test cases migrate as-is.
- NEW in-process Letsdo::Backends::Fake (test/helpers/fake_backend.rb): implements the protocol directly — scripted events via the streamer API, scripted exit code, scripted stop behavior. Backs the business-layer tests (Agent/AgentLoop/CLI/TUI) so they exercise the normalized protocol without subprocesses; it is also the reference implementation proving the interface is implementable. Existing cli/agent tests keep working through fake_pi (default pi backend + LETSDO_PI_COMMAND) — no force-migration, per the behavior-identical promise; gradual migration is optional at the developer's discretion.

3. REGISTRY / SELECTION (AC#3) — LETSDO_BACKEND env knob (default 'pi'), mirroring TASK-58's provider conventions:
- Letsdo::Config (TASK-53) reads LETSDO_BACKEND, default 'pi', empty/invalid -> default.
- Letsdo::CLI::Builder (TASK-54) owns the backend registry: BACKENDS = { 'pi' => Letsdo::Backends::Pi, 'fake' => Letsdo::Backends::Fake (test-only, registered by test helpers) }; each entry responds to .factory(config) -> lambda(prompt:, streamer:) -> backend instance. Unknown LETSDO_BACKEND fails fast: 'letsdo: unknown AI backend: <name>' + exit 1 (no silent fallback — same policy as TASK-58 AC#3).
- Agent delta: constructor takes backend_factory (callable) instead of flags/command; run = prompt_store.read(name) + @backend = factory.call(prompt:, streamer:) + @backend.run. attr_reader :runner -> attr_reader :backend (same purpose).
- AgentLoop delta: on_signal calls @agent&.backend&.terminate_now — same call shape, no protocol change. Loop / OutputStreamer / TUI: ZERO change (verified: Loop already generic; OutputStreamer is the normalized surface; TUI stop path is the Letsdo::Stopped unwind).
- What stays in business logic (backend-agnostic, pi vocabulary forbidden): PromptStore, OutputStreamer, Loop, AgentLoop, Agent (composition), CLI argv/usage, Config env policy, Builder wiring. What moves to the backend layer: pi command/flags/env knobs, spawn/parsing/fallbacks, exit-code mapping, process-group termination — all product-specific knowledge.

4. ROADMAP (AC#4) — second real backend as developer tasks, NOT implemented here. Claude Code first: 'claude -p <prompt> --output-format stream-json --verbose'; maps system/assistant/tool_use/tool_result stream items onto the normalized protocol; per-backend knobs LETSDO_CLAUDE_COMMAND/LETSDO_CLAUDE_FLAGS; same process-group termination. Cursor second (cursor-agent run), CLI less stable — lower priority. Both described in one roadmap task with ACs.

5. SEQUENCING / COORDINATION
- Phase-2 of the TASK-50 layout: backends/pi.rb reserved and moved ONCE by this spike's developer work (same rule as providers/ in TASK-51). Symmetry with TASK-51 naming: Letsdo::Backends (backends) vs Letsdo::Providers (providers); LETSDO_BACKEND vs LETSDO_PROVIDER.
- Deps: backend tasks land after TASK-42 (green baseline) and, for the selection half, after TASK-53 (Config) + TASK-54 (Builder) so LETSDO_BACKEND and the registry have their homes. fake_backend.rb in test/helpers/ — coordinate with TASK-55 (which creates the dir for shared fakes); no hard dependency.
- Conventions: English texts (TASK-35); rubocop 0 offenses (TASK-37) on landing; behavior identical (same env vars, same exit codes, plain output byte-identical); each task single-PR-sized.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike complete: designed the AI backend adapter seam (TASK-52). Normalized backend protocol specified in the task design comment: run -> exit code streaming text_delta/tool_start/tool_result/finish at the injected streamer, terminate_now/terminate, debug with LETSDO_DEBUG semantics — pi vocabulary confined to the adapter. Pi maps onto it as Letsdo::Backends::Pi (PiRunner moved once, lib/letsdo/backends/pi.rb per TASK-50 reservation; behavior identical incl. LETSDO_PI_COMMAND/FLAGS). Registry/selection: LETSDO_BACKEND (default pi) read by Letsdo::Config (TASK-53), registry in Letsdo::CLI::Builder (TASK-54); business-vs-adapter split made explicit (Loop/OutputStreamer/TUI untouched; Agent takes backend_factory; AgentLoop calls agent.backend.terminate_now). Test seams evaluated: fake_pi stays for pi-adapter tests, in-process Letsdo::Backends::Fake (test/helpers/fake_backend.rb) backs business-layer tests. Verified: design comment present (6 sections), developer tasks TASK-59/60/61 exist (To Do, @developer, ACs, English, referenced from TASK-52), code untouched (only backlog/ files from this spike; TASK-42 in-flight changes not staged).
<!-- SECTION:FINAL_SUMMARY:END -->
