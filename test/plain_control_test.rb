# frozen_string_literal: true

require 'pty'
require_relative 'test_helper'

# Non-blocking reads shared by the spawn helpers and the session wrapper.
module PlainControlIO
  def append(err_r, buffer)
    buffer << err_r.read_nonblock(4096)
  rescue IO::WaitReadable, EOFError, Errno::EPIPE
    nil
  end

  def drain(err_r, buffer)
    loop { buffer << err_r.read_nonblock(4096) }
  rescue IO::WaitReadable, EOFError, Errno::EPIPE, Errno::EBADF
    buffer
  end
end

# Spawn helpers for the plain-mode control subprocess test (TASK-75):
# stdout/stderr are pipes (plain mode) while only stdin is a PTY, so the
# control reader is genuinely engaged by the TTY gate, not a stub.
module PlainControlSpawnHelpers
  include PlainControlIO

  RUN_PATTERN = 'letsdo: running developer for TASK-1'

  def letsdo_script
    File.expand_path('../bin/letsdo', __dir__)
  end

  def plain_child_env(env)
    {
      'PATH' => ENV.fetch('PATH', ''),
      'LETSDO_PI_COMMAND' => fake_pi,
      'LETSDO_BACKLOG_COMMAND' => File.expand_path('fixtures/fake_backlog', __dir__),
      'LETSDO_WAIT_SECONDS' => '120'
    }.merge(env)
  end

  def spawn_plain_tty(root, env:)
    master, slave = PTY.open
    out_r, out_w = IO.pipe
    err_r, err_w = IO.pipe
    pid = spawn_child(root, env, slave, out_w, err_w)
    slave.close
    out_w.close
    err_w.close
    [pid, master, out_r, err_r]
  end

  def spawn_child(root, env, slave, out_w, err_w)
    Process.spawn(plain_child_env(env), RbConfig.ruby, letsdo_script, 'developer',
                  chdir: root, in: slave, out: out_w, err: err_w)
  end

  def running_env(ready_path)
    { 'FAKE_BACKLOG_SCENARIO' => 'open', 'FAKE_BACKLOG_COUNT' => '1',
      'FAKE_PI_SLEEP' => '300', 'FAKE_PI_READY_FILE' => ready_path }
  end

  def with_running_plain
    with_project('developer' => 'You are a developer.') do |root|
      session = start_plain_session(root)
      begin
        yield session
      ensure
        session.close
      end
    end
  end

  def start_plain_session(root)
    ready_path = File.join(Dir.mktmpdir('letsdo-ready'), 'ready')
    pid, master, out_r, err_r = spawn_plain_tty(root, env: running_env(ready_path))
    read_until(err_r, RUN_PATTERN)
    pi_pid = wait_for_ready_file(ready_path, timeout: 10)
    PlainControlSession.new(pid: pid, master: master, out_r: out_r,
                            err_r: err_r, pi_pid: pi_pid)
  end

  def read_until(err_r, pattern, timeout: 15)
    buffer = +''
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until buffer.include?(pattern)
      assert_overdue(deadline, pattern, buffer)
      next unless IO.select([err_r], nil, nil, 0.2)

      append(err_r, buffer)
    end
    buffer
  end

  def assert_overdue(deadline, pattern, buffer)
    remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_operator remaining, :>, 0, "timed out waiting for #{pattern.inspect}; got: #{buffer.inspect}"
  end
end

# A running plain-mode letsdo subprocess with a PTY stdin: wraps the process
# handles plus the pi child pid so the test methods stay small.
class PlainControlSession
  include PlainControlIO

  STOPPED_STATE = /^State:\s+T\b/

  def initialize(pid:, master:, out_r:, err_r:, pi_pid:)
    @pid = pid
    @master = master
    @out_r = out_r
    @err_r = err_r
    @pi_pid = pi_pid
    @buffer = +''
    @status = nil
  end

  # Sends one control command; the reader consumes it on its next line.
  def press(key)
    @master.write("#{key}\n")
  end

  def wait_pi_stopped(stopped)
    deadline = monotonic + 5
    until pi_stopped? == stopped
      raise "pi #{@pi_pid} never reached stopped=#{stopped}" if monotonic >= deadline

      sleep 0.01
    end
  end

  def quit
    press('q')
    @status = wait_status
  end

  def exitstatus
    @status&.exitstatus
  end

  def stderr
    @buffer = drain(@err_r, @buffer)
  end

  def stdout
    @out_r.read
  end

  def pi_alive?
    Process.kill(0, @pi_pid)
    true
  rescue Errno::ESRCH, Errno::EPERM
    false
  end

  def close
    kill
    [@master, @out_r, @err_r].each { |io| io.close unless io.closed? }
  rescue IOError
    nil
  end

  private

  def pi_stopped?
    File.read("/proc/#{@pi_pid}/status").match?(STOPPED_STATE)
  rescue Errno::ENOENT, Errno::EACCES
    false
  end

  def wait_status
    deadline = monotonic + 10
    loop do
      _, status = Process.waitpid2(@pid, Process::WNOHANG)
      return status if status
      raise 'letsdo did not exit within 10s' if monotonic >= deadline

      sleep 0.05
    end
  end

  def kill
    Process.kill('KILL', @pid)
    Process.waitpid(@pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

# Plain mode (stdout not a TTY) with a terminal stdin: p/q behave exactly
# like the TUI keys, while the byte stream itself stays plain (TASK-75).
class PlainControlTtyTest < Minitest::Test
  include PlainControlSpawnHelpers

  def test_p_freezes_then_resumes_the_pi_child
    with_running_plain do |session|
      session.press('p')
      session.wait_pi_stopped(true)
      session.press('p')
      session.wait_pi_stopped(false)
    end
  end

  def test_q_stops_cleanly_and_terminates_the_pi_child
    with_running_plain do |session|
      session.quit

      assert_equal 0, session.exitstatus
      assert_includes session.stderr, 'letsdo: stopped'
      refute session.pi_alive?, 'q must terminate the pi child'
      refute_includes session.stdout, "\e[", 'plain stdout must stay escape-free'
    end
  end
end
