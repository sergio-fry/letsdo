# frozen_string_literal: true

# The Letsdo package — a local agent worker for Backlog.md/markdown tasks.
#
# OOP structure:
#   Letsdo::Errors           - error hierarchy (Letsdo::Error and others)
#   Letsdo::PromptStore      - access to agents/*.md prompts
#   Letsdo::DefaultPrompt    - the built-in default prompt (fallback run, --init template)
#   Letsdo::AgentIdentity    - the identity block injected into every agent prompt
#   Letsdo::OutputStreamer   - where and how agent text and service lines are printed
#   Letsdo::Backends::Pi     - running pi --mode json and parsing the event stream
#   Letsdo::Agent            - a single agent run: prompt from agents/ or default + pi
#   Letsdo::Capture          - interruption-safe child stdout/stderr capture
#   Letsdo::BacklogTasks     - open tasks from the backlog CLI (the task provider)
#   Letsdo::Loop             - generic orchestrator: tasks → runs → waiting
#   Letsdo::RetryPolicy      - per-task retry/backoff/give-up policy (used at AgentLoop level)
#   Letsdo::AgentLoop        - letsdo wiring: provider + agent + signals + messages
#   Letsdo::Control          - agent-control primitives (PauseGate, Reader)
#   Letsdo::Doctor           - `letsdo doctor` environment self-check
#   Letsdo::Tui              - the interactive TUI (LogBuffer, Metrics,
#                              Renderer, Terminal, Input, Session)
#   Letsdo::CLI              - command-line arguments, usage, exit code
#
# Entry point — bin/letsdo (a thin wrapper over Letsdo::CLI).

require_relative 'letsdo/version'
require_relative 'letsdo/errors'
require_relative 'letsdo/duration'
require_relative 'letsdo/config'
require_relative 'letsdo/prompt_store'
require_relative 'letsdo/default_prompt'
require_relative 'letsdo/agent_identity'
require_relative 'letsdo/output_streamer'
require_relative 'letsdo/backends/backend'
require_relative 'letsdo/backends/pi'
require_relative 'letsdo/agent'
require_relative 'letsdo/capture'
require_relative 'letsdo/providers/backlog'
require_relative 'letsdo/loop'
require_relative 'letsdo/retry_policy'
require_relative 'letsdo/watcher'
require_relative 'letsdo/agent_loop'
require_relative 'letsdo/session_recorder'
require_relative 'letsdo/task_time_writeback'
require_relative 'letsdo/metrics/fanout'
require_relative 'letsdo/control'
require_relative 'letsdo/doctor'
require_relative 'letsdo/tui'
require_relative 'letsdo/cli'
