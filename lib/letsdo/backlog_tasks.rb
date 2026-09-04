# frozen_string_literal: true

require 'json'
require 'open3'
require 'shellwords'

module Letsdo
  # Task provider for Letsdo::Loop backed by the real backlog CLI:
  #
  #   backlog task list --assignee <handle> --exclude-status Done --json
  #
  # Returns the list of open tasks assigned to the handle (an Array, empty
  # when there are none), or nil when the backlog state is unreadable — the
  # CLI is not on PATH, failed, or its output is not the expected JSON. The
  # loop treats nil as "pause and retry, do not run the agent".
  #
  # The command runs in the project root (cwd), where the backlog CLI finds
  # the backlog/ folder — the same context as a single agent run.
  class BacklogTasks
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

    # Reads the open tasks once.
    #
    # @return [Array<Hash>, nil] open tasks; nil when the backlog is unreadable
    def call
      args = @env ? [@env, *command_line] : command_line
      out, _err, status = Open3.capture3(*args, chdir: @cwd)
      return nil unless status.success?

      tasks = JSON.parse(out)['tasks']
      tasks.is_a?(Array) ? tasks : nil
    rescue Errno::ENOENT, JSON::ParserError, TypeError
      nil
    end

    private

    # [command..., task, list, --assignee <handle>, --exclude-status Done, --json]
    def command_line
      [
        *Shellwords.split(@command),
        'task', 'list',
        '--assignee', @handle,
        '--exclude-status', 'Done',
        '--json'
      ]
    end
  end
end
