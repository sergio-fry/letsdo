# frozen_string_literal: true

require 'json'
require 'shellwords'
require_relative 'task'

module Letsdo
  module Providers
    # Task provider for Letsdo::Loop backed by the real backlog CLI:
    #
    #   backlog task list --assignee <handle> --exclude-status Done \
    #     --ready --sort priority --json
    #
    # Returns the runnable tasks assigned to the handle in the
    # authoritative run order (an Array of Letsdo::Providers::Task), or nil
    # when the backlog state is unreadable — the CLI is not on PATH, failed,
    # or its output is not the expected JSON. The loop treats nil as "pause
    # and retry, do not run the agent".
    #
    # The command runs in the project root (cwd), where the backlog CLI finds
    # the backlog/ folder — the same context as a single agent run.
    class Backlog
      # Keys of the normalized Letsdo::Providers::Task shape. The backlog CLI
      # emits more (reporter, parentTaskId, createdAt, updatedAt); the adapter
      # projects onto these and ignores the rest so a growing CLI schema
      # cannot crash the loop. Beyond the identity fields, the shape keeps
      # what deterministic selection needs: ordinal (the stable tie-break) and
      # type/labels/milestone (optional capability routing).
      TASK_FIELDS = %w[id title status priority assignees ordinal type labels milestone].freeze

      # Sort ranks for the deterministic batch order. Known priorities are
      # compared case-insensitively; anything else (nil or a new label) ranks
      # last instead of crashing the comparator.
      PRIORITY_RANKS = { 'high' => 0, 'medium' => 1, 'low' => 2 }.freeze
      UNKNOWN_RANK = PRIORITY_RANKS.size

      # @param handle [String] assignee handle to filter by (e.g. "@developer")
      # @param command [String] backlog CLI command (overridable for tests)
      # @param cwd [String, nil] project root for the CLI; nil = inherit cwd
      # @param env [Hash, nil] environment for the CLI child (nil = inherit
      #        the process environment; injected in tests to control the
      #        fake backlog scenarios)
      def initialize(handle:, command: 'backlog', cwd: nil, env: nil)
        @handle = handle
        @command = command
        @cwd = cwd
        @env = env
      end

      # Reads the runnable open tasks once, in deterministic run order.
      #
      # @return [Array<Task>, nil] runnable open tasks; nil when the backlog is
      #         unreadable; empty array when there are no open tasks
      def call
        args = @env ? [@env, *command_line] : command_line
        out, _err, status = Letsdo::Capture.new(*args, chdir: @cwd).run
        return nil unless status.success?

        tasks = JSON.parse(out)['tasks']
        tasks.is_a?(Array) ? sort(tasks.map { |raw| normalize(raw) }) : nil
      rescue Errno::ENOENT, JSON::ParserError, TypeError
        nil
      end

      private

      # Deterministic run order: In Progress first (resume before starting),
      # then priority High > Medium > Low, then ordinal ascending, then id
      # ascending. The CLI's --sort priority does not put In Progress first
      # and cannot express the full tie-break, so the adapter sorts the batch
      # itself. The original index is the final tie-break, so equal keys keep
      # the provider's (deterministic) order.
      def sort(tasks)
        tasks.each_with_index.sort_by do |task, index|
          [in_progress_rank(task), priority_rank(task.priority),
           ordinal_rank(task.ordinal), id_rank(task.id), index]
        end.map(&:first)
      end

      def in_progress_rank(task)
        task.status.to_s.casecmp('In Progress').zero? ? 0 : 1
      end

      def priority_rank(priority)
        PRIORITY_RANKS[priority.to_s.downcase] || UNKNOWN_RANK
      end

      # Unknown/nil ordinals sort last (their id still orders them).
      def ordinal_rank(ordinal)
        value = Integer(ordinal, exception: false)
        value.nil? ? [1, 0] : [0, value]
      end

      # An absent id (malformed task) sorts after identified ones.
      def id_rank(id)
        [id.to_s.empty? ? 1 : 0, id.to_s]
      end

      # Projects one raw CLI task onto the normalized shape. Unknown keys are
      # ignored (the CLI schema grows over time); a non-Hash entry means the
      # payload is not the expected schema and raises TypeError, which #call
      # turns into nil.
      def normalize(raw)
        raise TypeError, "task is not an object: #{raw.class}" unless raw.is_a?(Hash)

        Task.new(**TASK_FIELDS.to_h { |field| [field.to_sym, raw[field]] })
      end

      # [command..., task, list, --assignee <handle>, --exclude-status Done,
      #  --ready, --sort priority, --json]
      def command_line
        [
          *Shellwords.split(@command),
          'task', 'list',
          '--assignee', @handle,
          '--exclude-status', 'Done',
          '--ready',
          '--sort', 'priority',
          '--json'
        ]
      end
    end
  end
end
