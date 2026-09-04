# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class AgentLoopTest < Minitest::Test
  # Builds an AgentLoop with injected fakes and a sleeper that stops the
  # loop on its first wait (throw). Returns [loop, stderr].
  def make_loop(provider:, run_one:, wait_seconds: 0.5, sleeper: nil, stderr: nil)
    stderr ||= StringIO.new
    sleeper ||= lambda do |_seconds|
      throw Letsdo::AgentLoop::STOP
    end
    loop_obj = Letsdo::AgentLoop.new(
      name: "developer", handle: "@developer",
      run_one: run_one, task_provider: provider,
      wait_seconds: wait_seconds, sleeper: sleeper, stderr: stderr
    )
    [loop_obj, stderr]
  end

  # A provider that returns the given first batch, then no tasks.
  def once_provider(tasks)
    calls = 0
    lambda do
      calls += 1
      calls == 1 ? tasks : []
    end
  end

  def test_runs_one_agent_run_per_open_task
    runs = []
    provider = once_provider([{ "id" => "TASK-1" }, { "id" => "TASK-2" }])
    loop_obj, stderr = make_loop(provider: provider, run_one: ->(_task) { runs << :run; 0 })

    assert_equal 0, loop_obj.run
    assert_equal 2, runs.length
    assert_includes stderr.string, "letsdo: running developer for TASK-1"
    assert_includes stderr.string, "letsdo: running developer for TASK-2"
    assert_includes stderr.string, "letsdo: stopped"
  end

  def test_continues_after_nonzero_exit
    runs = []
    provider = once_provider([{ "id" => "TASK-1" }, { "id" => "TASK-2" }])
    loop_obj, stderr = make_loop(provider: provider, run_one: ->(_task) { runs << :run; 4 })

    assert_equal 0, loop_obj.run
    assert_equal 2, runs.length
    assert_includes stderr.string, "letsdo: developer exited with code 4"
  end

  def test_waits_when_no_tasks
    runs = []
    provider = -> { [] }
    loop_obj, stderr = make_loop(provider: provider, run_one: ->(_task) { runs << :run; 0 },
                                 wait_seconds: 1.5)

    assert_equal 0, loop_obj.run
    assert_empty runs
    assert_includes stderr.string, "letsdo: no open tasks for developer, retrying in 1.5s"
  end

  def test_pauses_when_backlog_unavailable
    runs = []
    provider = -> { nil }
    loop_obj, stderr = make_loop(provider: provider, run_one: ->(_task) { runs << :run; 0 })

    assert_equal 0, loop_obj.run
    assert_empty runs
    assert_includes stderr.string, "letsdo: backlog unavailable, retrying in 0.5s"
  end

  def test_sleeper_receives_wait_seconds
    seen = []
    provider = -> { [] }
    sleeper = lambda do |seconds|
      seen << seconds
      throw Letsdo::AgentLoop::STOP
    end
    loop_obj, = make_loop(provider: provider, run_one: ->(_task) { 0 }, wait_seconds: 0.25,
                          sleeper: sleeper)

    loop_obj.run
    assert_equal [0.25], seen
  end

  def test_task_label_falls_back_to_object
    runs = []
    provider = once_provider(["plain-task"])
    loop_obj, stderr = make_loop(provider: provider, run_one: ->(_task) { runs << :run; 0 })

    loop_obj.run
    assert_equal 1, runs.length
    assert_includes stderr.string, "letsdo: running developer for plain-task"
  end

  # --- TUI metrics facade events (TASK-42) ------------------------------

  # A recorder standing in for Letsdo::Tui::Metrics.
  class MetricsRecorder
    attr_reader :events

    def initialize
      @events = []
    end

    def provider_result(count)
      @events << [:provider, count]
    end

    def run_started(task)
      @events << [:start, task]
    end

    def run_finished
      @events << [:finish]
    end
  end

  def make_loop_with_metrics(provider:, metrics:, run_one: nil)
    stderr = StringIO.new
    Letsdo::AgentLoop.new(
      name: "developer", handle: "@developer", metrics: metrics,
      run_one: run_one || ->(_task) { 0 }, task_provider: provider,
      wait_seconds: 0.5, sleeper: ->(_s) { throw Letsdo::AgentLoop::STOP }, stderr: stderr
    )
  end

  def test_metrics_receives_provider_counts_and_run_events
    metrics = MetricsRecorder.new
    provider = once_provider([{ "id" => "TASK-1" }])

    make_loop_with_metrics(provider: provider, metrics: metrics).run

    assert_equal [[:provider, 1], [:start, "TASK-1"], [:finish], [:provider, 0]],
                 metrics.events
  end

  def test_metrics_receives_nil_when_the_backlog_is_unreadable
    metrics = MetricsRecorder.new

    make_loop_with_metrics(provider: -> { nil }, metrics: metrics).run

    assert_equal [[:provider, nil]], metrics.events
  end

  # --- signal handling (real process, real signals) ----------------------

  LIB_DIR = File.expand_path("../lib", __dir__)

  def letsdo_script
    File.expand_path("../bin/letsdo", __dir__)
  end

  # Spawns `bin/letsdo developer` in a temp project; returns [pid, err_r].
  # The child stderr is readable to wait for known messages.
  def spawn_letsdo(project_root, env: {})
    err_r, err_w = IO.pipe
    child_env = {
      "PATH" => ENV.fetch("PATH", ""),
      "LETSDO_PI_COMMAND" => fake_pi,
      "LETSDO_BACKLOG_COMMAND" => File.expand_path("fixtures/fake_backlog", __dir__),
      "LETSDO_WAIT_SECONDS" => "120"
    }.merge(env)
    # Ruby 4.0 removed the :env exec option: the child environment is passed
    # as a positional hash before the command.
    pid = Process.spawn(child_env, RbConfig.ruby, letsdo_script, "developer",
                        chdir: project_root, out: File::NULL, err: err_w)
    err_w.close
    [pid, err_r]
  end

  # Reads the child stderr until the pattern appears (or the timeout fails
  # the test). Returns the text collected so far.
  def read_stderr_until(err_r, pattern, timeout: 20)
    buffer = +""
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return buffer if buffer.include?(pattern)

      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      assert_operator remaining, :>, 0,
                      "timed out waiting for #{pattern.inspect}; got: #{buffer.inspect}"
      ready = IO.select([err_r], nil, nil, 0.2)
      next unless ready

      begin
        buffer << err_r.read_nonblock(4096)
      rescue IO::WaitReadable, EOFError, Errno::EPIPE
        next
      end
    end
  end

  # Drains the rest of the child stderr (until EOF) into the buffer.
  def drain_stderr(err_r, buffer)
    loop do
      buffer << err_r.read_nonblock(4096)
    end
  rescue IO::WaitReadable, EOFError, Errno::EPIPE, Errno::EBADF
    buffer
  end

  # Waits for the child to exit; asserts the exit code and that it happened
  # within the timeout.
  def assert_exit_within(pid, expected: 0, timeout: 15)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    status = nil
    loop do
      _pid, status = Process.waitpid2(pid, Process::WNOHANG)
      break if status

      assert_operator deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), :>, 0,
                      "child did not exit within #{timeout}s"
      sleep 0.05
    end
    assert_equal expected, status.exitstatus
  end

  def test_sigterm_stops_the_loop_during_an_agent_run
    with_project("developer" => "You are a developer.") do |root|
      pid, err_r = spawn_letsdo(root, env: {
                                  "FAKE_BACKLOG_SCENARIO" => "open", "FAKE_BACKLOG_COUNT" => "1",
                                  "FAKE_PI_SLEEP" => "300"
                                })
      stderr = read_stderr_until(err_r, "letsdo: running developer for TASK-1")
      Process.kill("TERM", pid)
      assert_exit_within(pid)
      stderr = drain_stderr(err_r, stderr)
      err_r.close
      assert_includes stderr, "letsdo: running developer for TASK-1"
      assert_includes stderr, "letsdo: stopped"
    end
  ensure
    terminate_leftover(err_r, pid) if defined?(err_r) && err_r && defined?(pid) && pid
  end

  def test_sigterm_stops_the_loop_while_waiting_fast
    with_project("developer" => "You are a developer.") do |root|
      pid, err_r = spawn_letsdo(root, env: { "FAKE_BACKLOG_SCENARIO" => "empty" })
      stderr = read_stderr_until(err_r, "letsdo: no open tasks for developer")
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      Process.kill("TERM", pid)
      assert_exit_within(pid, timeout: 8)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      stderr = drain_stderr(err_r, stderr)
      err_r.close
      assert_operator elapsed, :<, 5, "stop in wait mode took #{elapsed.round(2)}s"
      assert_includes stderr, "letsdo: stopped"
    end
  ensure
    terminate_leftover(err_r, pid) if defined?(err_r) && err_r && defined?(pid) && pid
  end

  def test_sigint_exits_cleanly
    with_project("developer" => "You are a developer.") do |root|
      pid, err_r = spawn_letsdo(root, env: { "FAKE_BACKLOG_SCENARIO" => "empty" })
      read_stderr_until(err_r, "letsdo: no open tasks for developer")
      Process.kill("INT", pid)
      assert_exit_within(pid)
      err_r.close
    end
  ensure
    terminate_leftover(err_r, pid) if defined?(err_r) && err_r && defined?(pid) && pid
  end

  # Kills a still-running child from an earlier failed assertion.
  def terminate_leftover(err_r, pid)
    begin
      Process.kill("KILL", pid)
      Process.waitpid(pid)
    rescue Errno::ESRCH, Errno::ECHILD
      nil
    end
    begin
      err_r.close unless err_r.closed?
    rescue IOError
      nil
    end
  end
end