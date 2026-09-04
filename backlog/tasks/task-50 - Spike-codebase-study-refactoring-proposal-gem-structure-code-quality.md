---
id: TASK-50
title: 'Spike: codebase study + refactoring proposal (gem structure, code quality)'
status: Done
assignee:
  - '@analyst'
created_date: '2026-09-04 07:10'
updated_date: '2026-09-04 07:33'
labels: []
dependencies: []
references:
  - TASK-53
  - TASK-54
  - TASK-55
type: spike
ordinal: 39000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Study the letsdo codebase and produce a refactoring proposal: what exactly to change in the project structure and code quality, ready to be broken down into developer tasks (per user request).

Current architecture (verified 2026-09-04): bin/letsdo is a thin wrapper over Letsdo::CLI. lib/letsdo.rb requires all components: errors.rb (Letsdo::Error, UnknownAgentError), prompt_store.rb (agents/*.md, list/read), output_streamer.rb (routes pi output: text_delta → stdout, tool lines → stderr, HH:MM:SS prefixes, big-output trimming), pi_runner.rb (spawns 'pi --mode json', reads line-by-line JSON events, propagates exit code, own process group + terminate), agent.rb (one run: PromptStore.read → PiRunner.run, keeps attr_reader :runner for termination), agent_loop.rb (signal handling, Letsdo::Stopped via trap), loop.rb (orchestrator, DI: task_provider + run_task injected — already clean), backlog_tasks.rb (Open3.capture3 'backlog task list --assignee <handle> --exclude-status Done --json', Array<Hash> or nil when unreadable), cli.rb (arg parsing + ALL env config: LETSDO_ROOT, LETSDO_PI_FLAGS/AGENT_PI_FLAGS, AGENT_ASSIGNEE_HANDLE, LETSDO_WAIT_SECONDS/AGENT_WAIT_SECONDS, LETSDO_PI_COMMAND, LETSDO_BACKLOG_COMMAND, LETSDO_DEBUG + wiring of agent/provider/loop). tests: Minitest, fixtures fake_pi (FAKE_PI_SCENARIO), fake_backlog.

Known coupling/issues to evaluate (verify and extend): PiRunner mixes three responsibilities (subprocess lifecycle, JSON event parsing, output formatting hooks); CLI mixes argument parsing + env config + object wiring; BacklogTasks is hardwired to the backlog CLI/schema; streaming semantics live in pi vocabulary (OutputStreamer consumes pi events via PiRunner). Goal: propose package layout that keeps behavior identical, improves testability, and stays open for new backends/providers (see related spikes TASK-51 backend adapter, TASK-52 backlog provider adapter — coordinate so the layouts match).

Deliverable: proposal documented in task comments (structure map, pain points, target layout, priorities, risks) + concrete developer tasks (@developer) with ACs, sized for single-PR. No code changes in this spike.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Complete architecture map documented in task comments: classes, responsibilities, coupling points, duplicate concerns, existing test seams
- [x] #2 Refactoring proposal with target gem layout (package structure staying compatible with future backends/providers from TASK-51/52), prioritized steps, risks, 'behavior stays identical' framing
- [x] #3 Concrete developer tasks created via backlog CLI (@developer) or listed as subtasks with ACs, each single-PR-sized
- [x] #4 Spike leaves the code untouched (no commits, no file edits)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Verify current state: code, tests, git working tree, related tasks (TASK-42 in-flight TUI, TASK-37 rubocop, TASK-44 --init, TASK-47 gemspec, TASK-51/52 spikes).
2. Record the architecture map in a task comment (AC#1): classes, responsibilities, coupling points, duplicate concerns, existing test seams.
3. Record the refactoring proposal in a comment (AC#2): target gem layout, prioritized phases, behavior-identical framing, risks.
4. Create single-PR-sized developer tasks via backlog CLI with ACs (AC#3), sequenced to avoid colliding with in-flight TASK-42/44.
5. Verify each AC with evidence, write final summary, move to Done, commit the backlog folder only (AC#4 — code untouched).
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Validation: (1) architecture map + proposal confirmed stored in the task file (comment bodies verified via grep: 'Architecture map (verified 2026-09-04...)' and 'Refactoring proposal' sections present). (2) TASK-53/54/55 verified as created: Status To Do, Assignee @developer, Dependencies TASK-42, 5-6 ACs each, referenced from TASK-50. (3) Code untouched: git status at end of the run shows only backlog/tasks/task-50 (modified) and backlog/tasks/task-53/54/55 (new) from this spike; all other working-tree changes (gemspec, lib/*, test/*, lib/letsdo/tui/*, test/tui_*_test.rb) pre-existed from in-flight TASK-42 and are NOT staged. (4) Test state noted: suite is currently red (14 failures / 10 errors, all in TASK-42 TUI tests, uncommitted) — Phase-1 tasks TASK-53/54/55 all depend on TASK-42 landing first so the baseline is green.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
author: @analyst
created: 2026-09-04 07:31
---
Architecture map (verified 2026-09-04, working tree incl. in-flight TASK-42 TUI):

COMPONENTS & RESPONSIBILITIES
- bin/letsdo (25 LoC): thin wrapper -> Letsdo::CLI.run(ARGV). Correct as is.
- lib/letsdo.rb: package entry, requires everything, module docstring (class inventory = duplication of README/gemspec description, TASK-47 fixes the gemspec side).
- errors.rb: Error < StandardError, UnknownAgentError (carries name), Stopped < Exception (deliberately not StandardError so nothing rescues it accidentally — the signal-unwind design). Clean, small, no coupling.
- prompt_store.rb: agents/*.md list/read; root injected; raises UnknownAgentError. Single responsibility, clean seam.
- output_streamer.rb: presentation layer — routes pi events to streams: text_delta -> stdout, tool/service lines -> stderr (HH:MM:SS prefixes, args summarization, truncation with summary note, completion lines with duration); in TASK-42 mode a log: target absorbs everything into Tui::LogBuffer. API names (text_delta/tool_start/tool_result) speak pi vocabulary.
- pi_runner.rb: THREE mixed responsibilities — (a) subprocess lifecycle (spawn in own group, terminate grace+kill, wait, exit codes incl. 128+signal), (b) pi JSON event parsing (message_update/text_delta, toolcall_start, tool_execution_start/end, agent_end + fallback placeholders), (c) event->streamer formatting hooks. Event vocabulary is the pi protocol itself (constants MESSAGE_UPDATE, TOOL_EXECUTION_START...). Signal design is subtle and documented: Letsdo::Stopped raise-in-trap interrupts the blocking read; notes for CRuby 4.0 M:N traps.
- agent.rb: one run = PromptStore.read(name) + build PiRunner directly (backend hardcoded to pi); attr_reader :runner for termination.
- backlog_tasks.rb: provider — Open3.capture3 'backlog task list --assignee <handle> --exclude-status Done --json', returns Array<Hash> or nil (CLI missing/failed/bad JSON). Hardwired to backlog CLI + its JSON schema ('tasks' key, task fields).
- loop.rb: orchestrator — callable task_provider (Array empty=wait, nil=retry), callable run_task, injectable sleeper, stop flag, returns run count. ALREADY CLEAN: pure DI, no letsdo classes referenced.
- agent_loop.rb: wiring + signals — builds Loop with wrapped_provider/wrapped_run lambdas, SIGINT/SIGTERM traps raise Letsdo::Stopped (handler only SIGTERMs the pi group), service messages on stderr ('letsdo: ...'), TASK-42 metrics hooks (provider_result/run_started/run_finished). task_label reads task["id"] — a provider-schema coupling threaded through the wiring layer.
- cli.rb: THREE mixed responsibilities — (a) argv parsing (--version/--help/unknown option/name; usage; exit codes), (b) ALL env config policy (LETSDO_ROOT, LETSDO_PI_FLAGS w/ AGENT_PI_FLAGS fallback, AGENT_ASSIGNEE_HANDLE, LETSDO_WAIT_SECONDS w/ AGENT_WAIT_SECONDS fallback, LETSDO_PI_COMMAND, LETSDO_BACKLOG_COMMAND, TERM; LETSDO_DEBUG read elsewhere), (c) object wiring (streamer/agent/provider/loop, in TASK-42 also TUI: log/metrics/terminal/input/session, refresh proc) + TUI-mode detection (stdout.tty? && stdin.tty? && TERM != dumb).
- tui/* (TASK-42, in working tree): log_buffer.rb (thread-safe append-only log, pending partial line, divider, version counter), metrics.rb (thread-safe facade; Snapshot struct), renderer.rb (pure (snapshot, lines, w/h, offset, follow, paused) -> framed String; display-width aware; lazy require unicode/display_width), terminal.rb (ANSI alt-screen/cursor wrapper on injected stream + size provider), input.rb (tty-reader wrapper -> key symbols, nonblocking poll, raw-escape mapping), session.rb (controller: alt-screen lifecycle, sole-repainter input thread, SIGWINCH flag, q/Ctrl-C quits via Thread.main.raise Letsdo::Stopped). Aggregator tui.rb.

COUPLING POINTS
1. Pi protocol vocabulary leaks into: PiRunner (parse), OutputStreamer (text_delta/tool_start/tool_result semantics), Agent (builds PiRunner + PiRunner::COMMAND default), CLI (LETSDO_PI_COMMAND/LETSDO_PI_FLAGS knobs). => TASK-52 territory (backend adapter).
2. Backlog CLI schema leaks into: BacklogTasks (hardwired), AgentLoop#task_label (reads task["id"]), CLI (LETSDO_BACKLOG_COMMAND). => TASK-51 territory (provider adapter).
3. Env defaulting policy is duplicated: CLI centralizes LETSDO_*/AGENT_* fallbacks for flags/wait; LETSDO_DEBUG is read directly inside PiRunner AND AgentLoop (nil -> ENV check in each class). Two different defaulting styles for the same family of variables.
4. Signal design threads through AgentLoop (traps) + PiRunner (raise interrupts blocking read, terminate path) + Tui::Session (SIGWINCH flag; quit reuses Letsdo::Stopped) — coherent but fragile; any change must keep the raise-in-trap contract (documented in pi_runner.rb).

DUPLICATE CONCERNS
- ENV-read + fallback policy: CLI (flags/wait) vs PiRunner/AgentLoop (debug).
- Duration/time formatting: OutputStreamer (wall-clock HH:MM:SS prefixes, completion durations 'Xs'/x.1fs) vs Tui::Renderer (elapsed HH:MM:SS from monotonic) — different purposes, small overlap, low priority.
- StringIO-based fakes: FakeTtyOut/FakeTtyIn defined inside cli_test.rb; TUI tests hand-roll similar StringIO/fake-size patterns in each test file (no shared helpers file).
- Result-line truncation vs screen fit (OutputStreamer#one_line/truncate_result vs Renderer#fit) — same idea, different constrains; merging would be artificial.

EXISTING TEST SEAMS (no mock framework — plain lambdas + fakes, per TASK-21)
- Loop: task_provider/run_task/sleeper injection (scheduled_provider, stop-after-first-wait). LoopTest 4 tests.
- AgentLoop: agent/run_one/task_provider/sleeper/stderr/metrics injection. 11 tests.
- CLI: run(argv, env:, stdout:, stderr:, stdin:, sleeper:) — full IO/env injection. 19 tests.
- PiRunner: command: override + fixtures/fake_pi + FAKE_PI_SCENARIO; 13 tests.
- BacklogTasks: command/cwd/env injection + fixtures/fake_backlog; 6 tests.
- OutputStreamer: stdout/stderr/log/clock injection; 25 tests.
- TUI (TASK-42): StringIO everywhere, injected size provider, scripted key bytes; 56 tests across 6 files.
- Test state today: 147 runs / 14 failures / 10 errors — all in TASK-42 TUI tests (in-flight, uncommitted). Non-TUI suites are green.
---

author: @analyst
created: 2026-09-04 07:31
---
Refactoring proposal

FRAMING: every step below keeps behavior identical — same env vars, same exit codes, same plain-mode output byte-identical, all existing tests stay green (TASK-42 must land and make the suite green first). Each step is one PR, independently testable, and reversible.

TARGET LAYOUT (final state, coordinates with TASK-51/52 — adapters live in their own namespaces; reserved now, filled by those spikes):

  lib/letsdo.rb                    # package entry + module doc
  lib/letsdo/version.rb
  lib/letsdo/errors.rb
  lib/letsdo/config.rb     [NEW]   # single env policy (Phase 1, task TS-1)
  lib/letsdo/cli.rb                # argv parsing + usage + exit codes only (Phase 1, task TS-2)
  lib/letsdo/cli/builder.rb [NEW]  # assembly/wiring of agent+provider+loop+TUI (Phase 1, TS-2)
  lib/letsdo/prompt_store.rb
  lib/letsdo/agent.rb
  lib/letsdo/loop.rb               # unchanged (already clean)
  lib/letsdo/agent_loop.rb
  lib/letsdo/output_streamer.rb
  lib/letsdo/backends/             # reserved for TASK-52 (pi adapter today)
    pi.rb                          # moved from pi_runner.rb BY TASK-52 (one move, not twice)
  lib/letsdo/providers/            # reserved for TASK-51 (backlog adapter today)
    backlog.rb                     # moved from backlog_tasks.rb BY TASK-51 (one move, not twice)
  lib/letsdo/tui/                  # intact (TASK-42)
  test/helpers/          [NEW]     # shared fakes (Phase 1, task TS-3)

PHASES (prioritized):
Phase 0 — preconditions (already scheduled elsewhere, NOT created here): TASK-42 lands + suite green; TASK-37 rubocop baseline; TASK-47 gemspec. Phase-1 tasks must pass rubocop (TASK-37) when they land.
Phase 1 — high-value, behavior-identical, no interface-design dependency:
  TS-1 Letsdo::Config: one env policy for ALL LETSDO_*/AGENT_* vars (+ LETSDO_DEBUG), removes per-class ENV reads in PiRunner/AgentLoop; unlocks future knobs (LETSDO_PROVIDER, LETSDO_BACKEND from TASK-51/52).
  TS-2 CLI split: parsing/usage/exit-codes stays in Letsdo::CLI; wiring (run_agent_plain/run_agent_tui, TUI detection, provider/agent/loop assembly) moves into Letsdo::CLI::Builder; CLI.run stays the facade. Sequencing: TASK-44 (--init) touches run(); land TS-2 after or coordinate — both keep the argv contract.
  TS-3 Shared test fakes: move FakeTtyOut/FakeTtyIn (currently inside cli_test.rb) + common TUI StringIO/size patterns into test/helpers/; zero behavioral change, purely test-harness dedup.
Phase 2 — owned by the adapter spikes (NOT duplicated here): pi_runner.rb -> backends/pi.rb + normalized backend protocol (TASK-52); backlog_tasks.rb -> providers/backlog.rb + TaskProvider interface + normalized task shape (TASK-51); then task_label/provider-schema couplings in AgentLoop/CLI dissolve naturally. TASK-50 only RESERVES the namespaces so the layout matches.
Phase 3 — optional, low priority (only if rubocop cleanup or the seams leave it on the table): shared duration/time formatting utility for OutputStreamer completion lines + TUI header; not worth a churn PR on its own.

RISKS
1. Collision with in-flight work: TASK-42 edits cli.rb, agent_loop.rb, output_streamer.rb, gemspec; TASK-44 edits the CLI argv path; TASK-39 (done) defined the loop semantics. Mitigation: Phase 1 starts only after TASK-42 merges; TS-2 explicitly coordinated with TASK-44; each step is a small diff on distinct files (config.rb is new; builder.rb is new; cli.rb shrinks).
2. Behavior-identical promise: the fake_pi/fake_backlog suites are the contract. Every Phase-1 task must land WITH tests that pin the existing env semantics: AGENT_PI_FLAGS/AGENT_WAIT_SECONDS fallback precedence (documented in cli.rb), LETSDO_DEBUG nil-default behavior, exit-code table (0/1/128+signal).
3. Env semantics drift during Config extraction: the two fallback styles (AGENT_* for flags/wait_seconds; plain LETSDO_DEBUG) must be preserved exactly as documented — the Config task's ACs must enumerate every variable and its current precedence.
4. Signal/threading design fragility: TS-1/TS-2 must NOT touch PiRunner's raise-in-trap contract or the TUI session threading model; any future change there has its own review bar (documented in pi_runner.rb).
5. Ruby version skew: local toolchain is Ruby 4.0.2, CI is 3.3 (TASK-47 AC#3 addresses the floor). Phase-1 code must use nothing 4.0-only.
6. Rename churn: backends/ and providers/ moves happen exactly ONCE, inside TASK-51/52 — TASK-50 does not move files, so no double-move cost.

Net effect: CLI loses its wiring/config load (3 responsibilities -> 1 + builder + config); env policy is testable in one place; the two adapter seams (TASK-51/52) slot into reserved namespaces with no layout conflict; Loop stays untouched; TUI stays intact.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Spike complete: studied the letsdo codebase (all 12 production files + 15 test files + fixtures) and produced the refactoring proposal as plan of record. Architecture map recorded as a comment (13 components with responsibilities, 3 coupling points, 4 duplicate concerns, 8 existing test seams). Proposal comment defines the target layout reserving lib/letsdo/backends/ (TASK-52) and lib/letsdo/providers/ (TASK-51) so adapter spikes fit without layout conflict, plus 4 prioritized phases with behavior-identical framing and 6 risks. Handed 3 single-PR-sized developer tasks to @developer (TASK-53 Letsdo::Config, TASK-54 CLI parse/wiring split via Letsdo::CLI::Builder, TASK-55 shared test fakes), each with 5-6 testable ACs and dep on TASK-42. Verification: AC#1/2 proven by comment bodies in the task file (grep), AC#3 by backlog task view of TASK-53/54/55 (assignee, deps, ACs), AC#4 by git status showing only backlog/ files changed by this spike — all 4 ACs checked; no production code touched.
<!-- SECTION:FINAL_SUMMARY:END -->
