# frozen_string_literal: true

require_relative 'test_helper'

# Letsdo::Watcher tests drive the real inotify backend against a temporary
# folder, plus the self-pipe polling fallback on an unwatchable path.
class WatcherTest < Minitest::Test
  def test_wait_returns_change_on_a_file_create
    Dir.mktmpdir('watcher') do |dir|
      watcher = Letsdo::Watcher.new(path: dir, poll_seconds: 5)

      File.write(File.join(dir, 'task.md'), 'x')

      assert_equal :change, watcher.wait(5)
    ensure
      watcher&.close
    end
  end

  def test_wait_times_out_without_changes
    Dir.mktmpdir('watcher') do |dir|
      watcher = Letsdo::Watcher.new(path: dir, poll_seconds: 0.05)

      assert_equal :timeout, watcher.wait(0.05)
    ensure
      watcher&.close
    end
  end

  def test_wake_interrupts_a_blocked_wait
    Dir.mktmpdir('watcher') do |dir|
      watcher = Letsdo::Watcher.new(path: dir, poll_seconds: 10)

      assert_wake_interrupts(watcher)
    ensure
      watcher&.close
    end
  end

  def test_locks_changes_do_not_wake_the_watcher
    Dir.mktmpdir('watcher') do |dir|
      watcher = Letsdo::Watcher.new(path: dir, poll_seconds: 0.2)

      FileUtils.mkdir_p(File.join(dir, '.locks'))
      File.write(File.join(dir, '.locks', 'lock.txt'), 'x')

      assert_equal :timeout, watcher.wait(0.2)
    ensure
      watcher&.close
    end
  end

  def test_fallback_polls_when_the_watch_is_unavailable
    missing = File.join(Dir.mktmpdir('watcher'), 'missing')
    watcher = Letsdo::Watcher.new(path: missing, poll_seconds: 0.05)

    assert_equal :timeout, watcher.wait(0.05)
  ensure
    watcher&.close
  end

  def test_fallback_wake_interrupts_the_poll
    missing = File.join(Dir.mktmpdir('watcher'), 'missing')
    watcher = Letsdo::Watcher.new(path: missing, poll_seconds: 10)

    assert_wake_interrupts(watcher)
  ensure
    watcher&.close
  end

  private

  def assert_wake_interrupts(watcher)
    result = nil
    thread = Thread.new { result = watcher.wait(10) }

    sleep 0.1
    watcher.wake
    thread.join(5)

    assert_equal :wake, result
    refute thread.alive?, 'wake did not release the blocked wait'
  end
end
