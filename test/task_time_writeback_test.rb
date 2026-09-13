# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'tempfile'

# Shared fakes for the Letsdo::TaskTimeWriteback tests (TASK-70).
module TaskTimeWritebackHelpers
  def setup
    @err = StringIO.new
  end

  def fake_backlog
    File.expand_path('fixtures/fake_backlog', __dir__)
  end

  def writeback(argv_file:, fail_edit: false, cwd: Dir.pwd)
    env = { 'FAKE_BACKLOG_ARGV_FILE' => argv_file }
    env['FAKE_BACKLOG_EDIT_FAIL'] = '1' if fail_edit
    Letsdo::TaskTimeWriteback.new(command: fake_backlog, cwd: cwd, env: env, stderr: @err)
  end

  def done_run(task, elapsed = 252.0)
    Letsdo::SessionRecorder::Run.new(task_id: task, elapsed_s: elapsed, exit_code: 0,
                                     outcome: :done)
  end

  def failed_run(task, elapsed = 10.0)
    Letsdo::SessionRecorder::Run.new(task_id: task, elapsed_s: elapsed, exit_code: 1,
                                     outcome: :failed)
  end

  def task(id)
    Letsdo::Providers::Task.new(id: id)
  end

  def argv_lines(path)
    File.exist?(path) ? File.read(path).lines.map(&:chomp) : []
  end

  def expected_comment(task, duration)
    "task|edit|#{task}|--comment|letsdo: completed in #{duration}|--comment-author|@letsdo"
  end
end

# The happy path: which runs get a comment, and the exact command line.
class TaskTimeWritebackTest < Minitest::Test
  include TaskTimeWritebackHelpers

  def test_completed_task_that_is_gone_gets_a_duration_comment
    Tempfile.create('argv') do |file|
      failures = writeback(argv_file: file.path).call([done_run('TASK-42')], [])

      assert_equal 0, failures
      assert_equal expected_comment('TASK-42', '4m 12s'), argv_lines(file.path).last
    end
  end

  def test_still_open_task_is_skipped
    Tempfile.create('argv') do |file|
      failures = writeback(argv_file: file.path).call([done_run('TASK-1')], [task('TASK-1')])

      assert_equal 0, failures
      assert_empty argv_lines(file.path)
    end
  end

  def test_failed_run_gets_no_comment
    Tempfile.create('argv') do |file|
      failures = writeback(argv_file: file.path).call([failed_run('TASK-1')], [])

      assert_equal 0, failures
      assert_empty argv_lines(file.path)
    end
  end

  def test_one_comment_per_task_even_after_a_retry
    Tempfile.create('argv') do |file|
      runs = [done_run('TASK-1', 60.0), done_run('TASK-1', 120.0)]
      failures = writeback(argv_file: file.path).call(runs, [])

      assert_equal 0, failures
      assert_equal 1, argv_lines(file.path).length
      assert_includes argv_lines(file.path).first, 'completed in 1m 0s'
    end
  end

  def test_each_closed_task_gets_its_own_comment
    Tempfile.create('argv') do |file|
      runs = [done_run('TASK-1', 60.0), done_run('TASK-2', 125.0)]
      failures = writeback(argv_file: file.path).call(runs, [])

      assert_equal 0, failures
      assert_equal [expected_comment('TASK-1', '1m 0s'),
                    expected_comment('TASK-2', '2m 5s')].sort,
                   argv_lines(file.path).sort
    end
  end
end

# Failure tolerance: a missing/renamed task, a failing command or an
# unreadable snapshot warn but never abort the stop path.
class TaskTimeWritebackFailureTest < Minitest::Test
  include TaskTimeWritebackHelpers

  def test_failing_edit_warns_once_and_is_counted
    Tempfile.create('argv') do |file|
      failures = writeback(argv_file: file.path, fail_edit: true).call([done_run('TASK-7')], [])

      assert_equal 1, failures
      assert_equal 1, @err.string.scan('cannot write task time comment for TASK-7').size
    end
  end

  def test_one_failure_does_not_stop_the_remaining_tasks
    Tempfile.create('argv') do |file|
      runs = [done_run('TASK-1'), done_run('TASK-2')]
      failures = writeback(argv_file: file.path, fail_edit: true).call(runs, [])

      assert_equal 2, failures
      assert_equal 1, @err.string.scan('for TASK-1').size
      assert_equal 1, @err.string.scan('for TASK-2').size
    end
  end

  def test_missing_command_does_not_raise
    wb = Letsdo::TaskTimeWriteback.new(command: 'letsdo_no_such_backlog_xyz', cwd: Dir.pwd,
                                       env: {}, stderr: @err)

    assert_equal 1, wb.call([done_run('TASK-1')], [])
    assert_includes @err.string, 'cannot write task time comment for TASK-1'
  end

  def test_unreadable_snapshot_writes_nothing_and_warns_once
    Tempfile.create('argv') do |file|
      failures = writeback(argv_file: file.path).call([done_run('TASK-1')], nil)

      assert_equal 0, failures
      assert_includes @err.string, 'backlog unreadable'
      assert_empty argv_lines(file.path)
    end
  end

  def test_unreadable_snapshot_is_silent_without_done_runs
    writeback(argv_file: '/dev/null').call([failed_run('TASK-1')], nil)

    assert_equal '', @err.string
  end
end
