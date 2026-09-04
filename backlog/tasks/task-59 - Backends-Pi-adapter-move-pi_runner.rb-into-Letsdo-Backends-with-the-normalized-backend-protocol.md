---
id: TASK-59
title: >-
  Backends::Pi adapter: move pi_runner.rb into Letsdo::Backends with the
  normalized backend protocol
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:41'
updated_date: '2026-09-04 10:27'
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
- [ ] #1 New lib/letsdo/backends/pi.rb: Letsdo::Backends::Pi — Letsdo::PiRunner moved there verbatim in behavior: 'pi --mode json <flags> <prompt>' spawned in its own process group, JSON line parsing (message_update/text_delta, toolcall_start, tool_execution_start/end, agent_end, pending-tools fallback), exit-code propagation (0/N/128+signal), terminate/terminate_now semantics, '[letsdo] pi:' debug prefix; LETSDO_PI_COMMAND/LETSDO_PI_FLAGS (AGENT_PI_FLAGS fallback) keep working — via Letsdo::Config if TASK-53 has landed, else exactly as today
- [ ] #2 Shared base lib/letsdo/backends/backend.rb: Letsdo::Backends::Backend — documented protocol (duck-typed contract + optional base providing the shared process lifecycle: spawn in own group, wait_status, exit-code semantics, terminate_now (trap-safe, no waits/IO), terminate(signal: 'TERM', grace: 3.0, tick: 0.05), debug helper). Normalized event vocabulary emitted at the injected streamer: text_delta / tool_start(name, args:) / tool_result(name, text, error:) / finish — exactly OutputStreamer's method set, finish called exactly once per run. Letsdo::Stopped raise-in-trap unwind preserved (CRuby 4.0 M:N notes stay in the pi adapter)
- [ ] #3 Letsdo::Agent consumes the seam: constructor takes backend_factory (lambda(prompt:, streamer:) -> backend) instead of flags/command; run = prompt_store.read + @backend = factory.call + @backend.run; attr_reader :runner renamed to :backend. Letsdo::AgentLoop#on_signal calls @agent&.backend&.terminate_now — same call shape, no protocol change. No pi vocabulary (message_update, tool_execution_*, agent_end) outside lib/letsdo/backends/
- [ ] #4 Tests migrated: test/pi_runner_test.rb -> test/backends/pi_test.rb reusing fake_pi (argv order via FAKE_PI_ARGV_FILE, exit codes, error/big/stub scenarios, terminate/terminate_now, noop-after-finish) against Letsdo::Backends::Pi; new test/helpers/fake_backend.rb — in-process Letsdo::Backends::Fake implementing the protocol (scripted events via streamer, scripted exit code, stop behavior) as reference + used by new Agent/AgentLoop factory-injection tests; existing fake_pi-based business tests pass unchanged (default pi backend)
- [ ] #5 rake test green (0 failures); rubocop over lib/, bin/, test/ reports 0 offenses (TASK-37); all texts in English (TASK-35); old Letsdo::PiRunner constant removed (no compat alias)
- [ ] #6 Affected letsdo components covered: lib/letsdo.rb (require + docstring), new lib/letsdo/backends/pi.rb and backend.rb, lib/letsdo/agent.rb, lib/letsdo/agent_loop.rb (on_signal + comment), tests; Letsdo::Loop, Letsdo::OutputStreamer and the TUI stay unchanged
<!-- AC:END -->
