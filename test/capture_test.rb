# frozen_string_literal: true

require_relative 'test_helper'
require 'rbconfig'

# Letsdo::Capture process handling (TASK-84): the child runs in its own
# process group, so an interrupted capture can terminate the whole group and
# no orphaned grandchild is left holding the output pipes.
class CaptureTest < Minitest::Test
  def test_spawns_child_in_its_own_process_group
    out, = Letsdo::Capture.new(RbConfig.ruby, '-e', 'puts Process.pid, Process.getpgrp').run
    pid, pgrp = out.split.map(&:to_i)

    assert_equal pid, pgrp
  end

  def test_interrupt_kills_the_child_group_including_grandchildren
    dir = Dir.mktmpdir('capture')
    child_pid, grandchild_pid = interrupt_capture(File.join(dir, 'child'),
                                                  File.join(dir, 'grandchild'))

    assert_dead(child_pid)
    assert_dead(grandchild_pid)
  end

  private

  # Runs a capture of a child that forks a grandchild holding the inherited
  # stdout, then raises a stop into the capture and returns both pids.
  def interrupt_capture(child_file, grandchild_file)
    capture = Letsdo::Capture.new(RbConfig.ruby, '-e', fork_script(child_file, grandchild_file))
    thread = Thread.new { capture.run }
    thread.report_on_exception = false

    child_pid = wait_for_ready_file(child_file, timeout: 5)
    grandchild_pid = wait_for_ready_file(grandchild_file, timeout: 5)
    thread.raise(Letsdo::Stopped)
    assert_raises(Letsdo::Stopped) { thread.join(5) }
    [child_pid, grandchild_pid]
  ensure
    thread&.kill if thread&.alive?
  end

  # A child that forks a grandchild holding the inherited stdout, then both
  # sleep — the shape that left an orphan holding the pipe before the fix.
  def fork_script(child_file, grandchild_file)
    <<~RUBY
      grandchild = fork do
        File.write('#{grandchild_file}', Process.pid.to_s)
        sleep 30
      end
      File.write('#{child_file}', Process.pid.to_s)
      sleep 30
      Process.wait(grandchild)
    RUBY
  end

  def assert_dead(pid, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return if dead?(pid)

      flunk "pid #{pid} is still alive after an interrupted capture" if overdue?(deadline)
      sleep 0.02
    end
  end

  def dead?(pid)
    Process.kill(0, pid)
    false
  rescue Errno::ESRCH
    true
  end
end
