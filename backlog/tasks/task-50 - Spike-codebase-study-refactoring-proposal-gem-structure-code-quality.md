---
id: TASK-50
title: 'Spike: codebase study + refactoring proposal (gem structure, code quality)'
status: To Do
assignee:
  - '@analyst'
created_date: '2026-09-04 07:10'
labels: []
dependencies: []
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
- [ ] #1 Complete architecture map documented in task comments: classes, responsibilities, coupling points, duplicate concerns, existing test seams
- [ ] #2 Refactoring proposal with target gem layout (package structure staying compatible with future backends/providers from TASK-51/52), prioritized steps, risks, 'behavior stays identical' framing
- [ ] #3 Concrete developer tasks created via backlog CLI (@developer) or listed as subtasks with ACs, each single-PR-sized
- [ ] #4 Spike leaves the code untouched (no commits, no file edits)
<!-- AC:END -->
