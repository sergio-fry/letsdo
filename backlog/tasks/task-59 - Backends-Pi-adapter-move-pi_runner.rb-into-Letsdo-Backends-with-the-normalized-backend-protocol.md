---
id: TASK-59
title: >-
  Backends::Pi adapter: move pi_runner.rb into Letsdo::Backends with the
  normalized backend protocol
status: Done
assignee:
  - '@developer'
created_date: '2026-09-04 07:41'
updated_date: '2026-09-10 19:01'
labels: []
dependencies:
  - TASK-42
references:
  - TASK-52
priority: medium
type: enhancement
ordinal: 48000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Part of the TASK-52 spike (AI backend adapter seam), Phase 2 of the TASK-50 refactoring layout: lib/letsdo/backends/ is the reserved namespace for AI/agent backends. Today Letsdo::PiRunner mixes three concerns (subprocess lifecycle, pi JSON event parsing, streamer formatting hooks), Letsdo::Agent builds it directly (flags/command passed down from CLI) and the business layer knows pi vocabulary. This task moves the runner into Letsdo::Backends::Pi behind a documented backend protocol (run -> exit code while streaming normalized events; terminate_now/terminate; debug with LETSDO_DEBUG semantics), so business logic stops depending on pi specifics. Behavior stays identical: same spawn command, same env knobs/fallbacks, same exit codes, plain output byte-identical; Letsdo::Loop and Letsdo::OutputStreamer are untouched (OutputStreamer's text_delta/tool_start/tool_result/finish IS the normalized stream surface).
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 New lib/letsdo/backends/pi.rb: Letsdo::Backends::Pi — Letsdo::PiRunner moved there verbatim in behavior: 'pi --mode json <flags> <prompt>' spawned in its own process group, JSON line parsing (message_update/text_delta, toolcall_start, tool_execution_start/end, agent_end, pending-tools fallback), exit-code propagation (0/N/128+signal), terminate/terminate_now semantics, '[letsdo] pi:' debug prefix; LETSDO_PI_COMMAND/LETSDO_PI_FLAGS (AGENT_PI_FLAGS fallback) keep working — via Letsdo::Config if TASK-53 has landed, else exactly as today
- [x] #2 Shared base lib/letsdo/backends/backend.rb: Letsdo::Backends::Backend — documented protocol (duck-typed contract + optional base providing the shared process lifecycle: spawn in own group, wait_status, exit-code semantics, terminate_now (trap-safe, no waits/IO), terminate(signal: 'TERM', grace: 3.0, tick: 0.05), debug helper). Normalized event vocabulary emitted at the injected streamer: text_delta / tool_start(name, args:) / tool_result(name, text, error:) / finish — exactly OutputStreamer's method set, finish called exactly once per run. Letsdo::Stopped raise-in-trap unwind preserved (CRuby 4.0 M:N notes stay in the pi adapter)
- [x] #3 Letsdo::Agent consumes the seam: constructor takes backend_factory (lambda(prompt:, streamer:) -> backend) instead of flags/command; run = prompt_store.read + @backend = factory.call + @backend.run; attr_reader :runner renamed to :backend. Letsdo::AgentLoop#on_signal calls @agent&.backend&.terminate_now — same call shape, no protocol change. No pi vocabulary (message_update, tool_execution_*, agent_end) outside lib/letsdo/backends/
- [x] #4 Tests migrated: test/pi_runner_test.rb -> test/backends/pi_test.rb reusing fake_pi (argv order via FAKE_PI_ARGV_FILE, exit codes, error/big/stub scenarios, terminate/terminate_now, noop-after-finish) against Letsdo::Backends::Pi; new test/helpers/fake_backend.rb — in-process Letsdo::Backends::Fake implementing the protocol (scripted events via streamer, scripted exit code, stop behavior) as reference + used by new Agent/AgentLoop factory-injection tests; existing fake_pi-based business tests pass unchanged (default pi backend)
- [x] #5 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35); old Letsdo::PiRunner constant removed (no compat alias)
- [x] #6 Affected letsdo components covered: lib/letsdo.rb (require + docstring), new lib/letsdo/backends/pi.rb and backend.rb, lib/letsdo/agent.rb, lib/letsdo/agent_loop.rb (on_signal + comment), tests; Letsdo::Loop, Letsdo::OutputStreamer and the TUI stay unchanged
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Create lib/letsdo/backends/backend.rb — Letsdo::Backends::Backend protocol + shared process lifecycle (spawn in own group, wait_status, exit-code semantics, terminate_now trap-safe, terminate, debug helper). One file ~95 lines. 2. Create lib/letsdo/backends/pi.rb — Letsdo::Backends::Pi < Backend with constants, event parsing module include, run/drain/close/finish/pause/resume/debug. 3. Create lib/letsdo/backends/pi/events.rb — Letsdo::Backends::Pi::Events module with read_pi_stream, handle_line, dispatch_event etc. 4. Modify lib/letsdo/agent.rb — constructor takes backend_factory (lambda(prompt:, streamer:, model:) -> backend) instead of flags/command; run reads prompt_store + config + factory.call(prompt:, streamer:, model: config[:model]) + @backend.run; attr_reader :backend. 5. Modify lib/letsdo/agent_loop.rb — on_signal calls @agent&.backend&.terminate_now + update comment. 6. Modify lib/letsdo/cli/builder.rb — pi_backend_factory closure with flags/model; agent_for uses it; tui_session_args runner -> agent.backend; Builder agent_for builds pi backend factory with pi_command/flags from Config. 7. Delete lib/letsdo/pi_runner.rb and subs; remove require from lib/letsdo.rb; update docstring; add backend/pi requires. 8. Create test/backends/pi_test.rb from pi_runner_test.rb (class renamed, references updated). 9. Create test/helpers/fake_backend.rb — Letsdo::Backends::Fake implementing protocol. 10. Update test/agent_test.rb make_agent factory injection; model tests still pass. 11. Add factory-injection test to test/agent_loop_test.rb. 12. Run all tests + rubocop verify 0 offenses.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation notes: PiRunner moved to Letsdo::Backends::Pi verbatim in behavior; backends/backend.rb provides the documented protocol + shared process lifecycle; Agent takes backend_factory and exposes attr_reader :backend; AgentLoop#on_signal calls @agent&.backend&.terminate_now; tests migrated to test/backends/pi_test.rb with test/helpers/fake_backend.rb in-process fake; new factory-injection tests cover the AgentLoop backend-termination seam. Verification: rake test -> 260 runs, 0 failures, 0 errors, 0 skips; rubocop -> 58 files, 0 offenses; no Letsdo::PiRunner references remain in lib/test/bin.
<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->
created: 2026-09-10 18:57
---
All acceptance criteria verified: tests green (0 failures), rubocop passes, PiRunner moved to Backends::Pi with normalized backend protocol, Agent and AgentLoop refactored, components covered.
---
<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Moved Letsdo::PiRunner into Letsdo::Backends::Pi behind a documented backend protocol (Letsdo::Backends::Backend): pi.rb spawns 'pi --mode json <flags> <prompt>' in its own process group and streams normalized events (text_delta/tool_start/tool_result/finish) to the injected streamer; backend.rb carries the shared process lifecycle (wait_status, exit-code semantics 0/N/128+signal, terminate_now trap-safe, terminate(signal:, grace:, tick:), debug '[letsdo] pi:'), preserving the Letsdo::Stopped raise-in-trap unwind. Letsdo::Agent now takes a backend_factory instead of flags/command and exposes attr_reader :backend; AgentLoop#on_signal calls @agent&.backend&.terminate_now. CLI::Builder builds the pi factory from Letsdo::Config (LETSDO_PI_COMMAND/PI_FLAGS with AGENT_PI_FLAGS fallback). Old pi_runner.rb/events.rb/process.rb deleted, lib/letsdo.rb requires and docstring updated, all stale PiRunner comments fixed. Tests migrated to test/backends/pi_test.rb against fake_pi; new test/helpers/fake_backend.rb provides Letsdo::Backends::Fake for factory-injection tests; new AgentLoop tests cover the terminate_now seam. Verified: rake test -> 260 runs, 0 failures, 0 errors, 0 skips; rubocop -> 58 files, 0 offenses; no Letsdo::PiRunner references remain in lib/test/bin.
<!-- SECTION:FINAL_SUMMARY:END -->
