# frozen_string_literal: true

# The Letsdo package — a local agent worker for Backlog.md/markdown tasks.
#
# OOP structure:
#   Letsdo::Errors           - error hierarchy (UnknownAgentError and others)
#   Letsdo::PromptStore      - access to agents/*.md prompts
#   Letsdo::OutputStreamer   - where and how agent text and service lines are printed
#   Letsdo::PiRunner         - running pi --mode json and parsing the event stream
#   Letsdo::Agent            - a single agent run: prompt from agents/ + pi
#   Letsdo::BacklogTasks     - open tasks from the backlog CLI (the task provider)
#   Letsdo::Loop             - generic orchestrator: tasks → runs → waiting
#   Letsdo::AgentLoop        - letsdo wiring: provider + agent + signals + messages
#   Letsdo::CLI              - command-line arguments, usage, exit code
#
# Entry point — bin/letsdo (a thin wrapper over Letsdo::CLI).

require_relative "letsdo/version"
require_relative "letsdo/errors"
require_relative "letsdo/prompt_store"
require_relative "letsdo/output_streamer"
require_relative "letsdo/pi_runner"
require_relative "letsdo/agent"
require_relative "letsdo/backlog_tasks"
require_relative "letsdo/loop"
require_relative "letsdo/agent_loop"
require_relative "letsdo/cli"