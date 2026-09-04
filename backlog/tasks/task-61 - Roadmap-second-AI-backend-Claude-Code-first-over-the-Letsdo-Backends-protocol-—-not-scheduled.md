---
id: TASK-61
title: >-
  Roadmap: second AI backend (Claude Code first) over the Letsdo::Backends
  protocol — not scheduled
status: To Do
assignee:
  - '@developer'
created_date: '2026-09-04 07:42'
labels: []
dependencies:
  - TASK-60
references:
  - TASK-52
type: feature
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Roadmap placeholder from the TASK-52 spike: future AI/agent backends (Claude Code, Cursor) are NOT implemented now. This task pins the acceptance contract a second backend must satisfy once one is actually needed; at scheduling time the implementer copies these ACs into a fresh task. Backbone: an adapter in lib/letsdo/backends/ implementing the backend protocol (run -> exit code, streaming text_delta/tool_start/tool_result/finish at the injected streamer, terminate_now/terminate, debug), backend CLI schema mapped inside the adapter, registration in the Builder registry under its LETSDO_BACKEND value, per-backend env knobs in their own namespace.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Documents the landing path for any backend: adapter in lib/letsdo/backends/ (e.g. claude_code.rb) implementing the protocol — run returns the child exit code (0/N/128+signal), normalized events streamed at the injected streamer (text_delta/tool_start/tool_result/finish exactly once), terminate_now trap-safe + terminate(grace) process-group stop, debug with '[letsdo] <backend>:' prefix; registration in the Builder backend registry (LETSDO_BACKEND value); per-backend env knobs in the backend's own namespace (LETSDO_CLAUDE_COMMAND/LETSDO_CLAUDE_FLAGS style), never read by business logic
- [ ] #2 Claude Code specified as the first concrete case: 'claude -p <prompt> --output-format stream-json --verbose' (or the current CLI equivalent); stream items mapped onto the protocol — assistant text -> text_delta, tool_use (name + input) -> tool_start, tool_result (content + is_error) -> tool_result, end-of-stream -> finish; exit-code mapping verified against the real CLI; nil/error handling for missing CLI or failed auth
- [ ] #3 Cursor listed as the second candidate with its mapping surface (cursor-agent run, stream-json mode) and noted as lower priority because its CLI is less stable
- [ ] #4 Explicit roadmap item: nothing is implemented or scheduled with this task; its ACs become the acceptance checklist of the future implementation task at scheduling time; all texts in English (TASK-35)
<!-- AC:END -->
