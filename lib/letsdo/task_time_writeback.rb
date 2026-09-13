# frozen_string_literal: true

require 'shellwords'
require_relative 'duration'
require_relative 'capture'

module Letsdo
  # Opt-in per-task elapsed write-back (TASK-70; design TASK-63 C3.3).
  #
  # At session stop the CLI hands this provider-agnostic writer the session's
  # run records and one fresh provider snapshot. Every run that exited 0 and
  # whose task is no longer open gets a backlog comment recording the elapsed
  # time:
  #
  #   backlog task edit <id> --comment 'letsdo: completed in 4m 12s' \
  #           --comment-author @letsdo
  #
  # A task that is still open after its run is skipped — calling it completed
  # would be wrong. The write-back is batched at stop (all agent runs are
  # dead), so it cannot race the agent's own closing edit on the file-based
  # backlog CLI.
  #
  # Failures never abort the stop path: a missing/renamed task or a failing
  # command warns once for that task and is counted, so the summary can report
  # how many comments were not written.
  class TaskTimeWriteback
    COMMENT_AUTHOR = '@letsdo'
    COMMENT_PREFIX = 'letsdo: completed in'

    # @param command [String] backlog CLI command (LETSDO_BACKLOG_COMMAND)
    # @param cwd [String] project root the CLI runs in
    # @param env [Hash, nil] child environment (nil = inherit the process one)
    # @param stderr [IO] warning sink
    def initialize(command:, cwd:, env: nil, stderr: $stderr)
      @command = command
      @cwd = cwd
      @env = env
      @stderr = stderr
    end

    # Writes one comment per eligible run.
    #
    # @param runs [Array<SessionRecorder::Run>] the session's run records
    # @param open_tasks [Array<Providers::Task>, nil] fresh provider snapshot;
    #        nil when the backlog is unreadable (nothing can be verified)
    # @return [Integer] number of comments not written
    def call(runs, open_tasks)
      return skip_unreadable(runs) if open_tasks.nil?

      open_ids = open_tasks.map(&:id)
      eligible(runs, open_ids).count { |run| !write(run) }
    end

    private

    # Done runs whose task is absent from the fresh snapshot, one entry per
    # task (a task retried after a late success cannot get two comments).
    def eligible(runs, open_ids)
      runs.select { |run| run.outcome == :done }
          .reject { |run| open_ids.include?(run.task_id) }
          .uniq(&:task_id)
    end

    # Without a readable snapshot we cannot tell closed from still-open, so we
    # write nothing and warn once instead of guessing.
    def skip_unreadable(runs)
      return 0 if runs.none? { |run| run.outcome == :done }

      @stderr.puts('letsdo: cannot write task time comments: backlog unreadable')
      0
    end

    def write(run)
      _out, err, status = capture(run)
      return true if status.success?

      warn_once(run, failure_message(err, status))
      false
    rescue StandardError => e
      warn_once(run, e.message)
      false
    end

    def capture(run)
      args = @env ? [@env, *argv(run)] : argv(run)
      Letsdo::Capture.new(*args, chdir: @cwd).run
    end

    def argv(run)
      [*Shellwords.split(@command), 'task', 'edit', run.task_id,
       '--comment', "#{COMMENT_PREFIX} #{Duration.format(run.elapsed_s)}",
       '--comment-author', COMMENT_AUTHOR]
    end

    def warn_once(run, reason)
      @stderr.puts("letsdo: cannot write task time comment for #{run.task_id}: #{reason}")
    end

    def failure_message(err, status)
      message = err.to_s.strip
      return message unless message.empty?

      "backlog exited with code #{status.exitstatus}"
    end
  end
end
