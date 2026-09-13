# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# AgentLoop tests inject fakes for the provider, run_one, and sleeper.
# The base class holds the shared harness; each concern below is its own
# test class so every class stays within the default length limits.
class AgentLoopTest < Minitest::Test
  def make_loop(provider:, run_one:, **opts)
    stderr = opts[:stderr] || StringIO.new
    loop_obj = Letsdo::AgentLoop.new(
      name: 'developer', handle: '@developer',
      run_one: run_one, task_provider: provider,
      wait_seconds: opts.fetch(:wait_seconds, 0.5),
      sleeper: opts[:sleeper] || default_sleeper, stderr: stderr,
      pause_gate: opts[:pause_gate], agent: opts[:agent],
      retry_policy: opts[:retry_policy]
    )
    [loop_obj, stderr]
  end

  def default_sleeper
    ->(_seconds) { throw Letsdo::AgentLoop::STOP }
  end

  def once_provider(tasks)
    calls = 0
    lambda do
      calls += 1
      calls == 1 ? tasks.map { |t| coerce_task(t) } : []
    end
  end

  def always_provider(tasks)
    -> { tasks.map { |t| coerce_task(t) } }
  end

  def counting_sleeper(max_sleeps:)
    calls = 0
    lambda do |_seconds|
      calls += 1
      throw Letsdo::AgentLoop::STOP if calls >= max_sleeps
    end
  end

  def coerce_task(task)
    return task if task.respond_to?(:id)
    return Letsdo::Providers::Task.new(**task.transform_keys(&:to_sym)) if task.is_a?(Hash)

    task
  end

  def counting_runner(runs, code = 0)
    lambda do |_task|
      runs << :run
      code
    end
  end
end

# Core loop: one run per task, wait, backlog pause, labels.
class AgentLoopRunTest < AgentLoopTest
  def test_runs_one_agent_run_per_open_task
    runs = []
    loop_obj, stderr = make_loop(provider: two_tasks, run_one: counting_runner(runs))

    assert_equal 0, loop_obj.run
    assert_equal 2, runs.length
    assert_includes stderr.string, 'letsdo: running developer for TASK-1'
    assert_includes stderr.string, 'letsdo: running developer for TASK-2'
    assert_includes stderr.string, 'letsdo: stopped'
  end

  def two_tasks
    once_provider([{ 'id' => 'TASK-1' }, { 'id' => 'TASK-2' }])
  end

  def test_continues_after_nonzero_exit
    runs = []
    loop_obj, stderr = make_loop(provider: two_tasks, run_one: counting_runner(runs, 4))

    assert_equal 0, loop_obj.run
    assert_equal 2, runs.length
    assert_includes stderr.string, 'letsdo: developer exited with code 4'
  end

  def test_waits_when_no_tasks
    runs = []
    loop_obj, stderr = make_loop(provider: -> { [] }, run_one: counting_runner(runs),
                                 wait_seconds: 1.5)

    assert_equal 0, loop_obj.run
    assert_empty runs
    assert_includes stderr.string, 'letsdo: no open tasks for developer, retrying in 1.5s'
  end

  def test_pauses_when_backlog_unavailable
    runs = []
    loop_obj, stderr = make_loop(provider: -> { nil }, run_one: counting_runner(runs))

    assert_equal 0, loop_obj.run
    assert_empty runs
    assert_includes stderr.string, 'letsdo: backlog unavailable, retrying in 0.5s'
  end

  def test_sleeper_receives_wait_seconds
    seen = []
    sleeper = lambda do |seconds|
      seen << seconds
      throw Letsdo::AgentLoop::STOP
    end
    loop_obj, = make_loop(provider: -> { [] }, run_one: ->(_task) { 0 },
                          wait_seconds: 0.25, sleeper: sleeper)

    loop_obj.run
    assert_equal [0.25], seen
  end

  def test_task_label_falls_back_to_object
    runs = []
    loop_obj, stderr = make_loop(provider: once_provider(['plain-task']),
                                 run_one: counting_runner(runs))

    loop_obj.run
    assert_equal 1, runs.length
    assert_includes stderr.string, 'letsdo: running developer for plain-task'
  end
end

# A recorder standing in for Letsdo::Tui::Metrics.
class AgentLoopMetricsRecorder
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

  def run_finished(exit_code = nil)
    @events << [:finish, exit_code]
  end
end

# TUI metrics facade events (TASK-42).
class AgentLoopMetricsTest < AgentLoopTest
  def make_loop_with_metrics(provider:, metrics:, run_one: ->(_task) { 0 })
    Letsdo::AgentLoop.new(
      name: 'developer', handle: '@developer', metrics: metrics,
      run_one: run_one, task_provider: provider,
      wait_seconds: 0.5, sleeper: default_sleeper, stderr: StringIO.new
    )
  end

  def test_metrics_receives_provider_counts_and_run_events
    metrics = AgentLoopMetricsRecorder.new
    make_loop_with_metrics(provider: once_provider([{ 'id' => 'TASK-1' }]),
                           metrics: metrics).run

    assert_equal [[:provider, 1], [:start, 'TASK-1'], [:finish, 0], [:provider, 0]],
                 metrics.events
  end

  def test_metrics_receives_the_run_exit_code
    metrics = AgentLoopMetricsRecorder.new
    make_loop_with_metrics(provider: once_provider([{ 'id' => 'TASK-1' }]),
                           run_one: ->(_task) { 7 }, metrics: metrics).run

    assert_equal [[:provider, 1], [:start, 'TASK-1'], [:finish, 7], [:provider, 0]],
                 metrics.events
  end

  def test_metrics_receives_nil_when_the_backlog_is_unreadable
    metrics = AgentLoopMetricsRecorder.new
    make_loop_with_metrics(provider: -> { nil }, metrics: metrics).run

    assert_equal [[:provider, nil]], metrics.events
  end
end

# Pause gate (TASK-74): between-runs pause, stop while paused.
class AgentLoopPauseTest < AgentLoopTest
  def gated_sleeper(wait_seconds:)
    lambda do |seconds|
      if seconds == wait_seconds
        throw Letsdo::AgentLoop::STOP
      else
        sleep(seconds)
      end
    end
  end

  def test_pause_gate_defaults_to_noop
    runs = []
    loop_obj, = make_loop(provider: once_provider([{ 'id' => 'TASK-1' }]),
                          run_one: counting_runner(runs))

    assert_equal 0, loop_obj.run
    assert_equal 1, runs.length
  end

  def test_paused_gate_blocks_new_runs_until_resume
    gate = Letsdo::Control::PauseGate.new
    gate.pause
    runs = []
    loop_obj, = paused_loop(gate, runs)

    thread = Thread.new { loop_obj.run }
    sleep 0.2
    assert_empty runs, 'no run may start while paused'
    gate.resume
    join_loop(thread)
    assert_equal 1, runs.length, 'the queued task must run after resume'
  end

  def paused_loop(gate, runs)
    make_loop(provider: once_provider([{ 'id' => 'TASK-1' }]), wait_seconds: 0.3,
              run_one: counting_runner(runs),
              sleeper: gated_sleeper(wait_seconds: 0.3), pause_gate: gate)
  end

  def join_loop(thread)
    thread.join(5)
    refute thread.alive?, 'loop did not stop after resume + empty backlog'
  end

  def test_stop_throws_interrupt_the_gate_wait
    gate = Letsdo::Control::PauseGate.new
    gate.pause
    loop_obj, stderr = make_loop(provider: once_provider([{ 'id' => 'TASK-1' }]),
                                 run_one: ->(_task) { 0 },
                                 sleeper: default_sleeper, pause_gate: gate)

    assert_equal 0, loop_obj.run
    assert_includes stderr.string, 'letsdo: stopped'
  end

  def test_stopped_raised_into_the_loop_interrupts_the_gate_wait
    gate = Letsdo::Control::PauseGate.new
    gate.pause
    loop_obj, stderr = sleeping_paused_loop(gate)
    thread = Thread.new { loop_obj.run }
    sleep 0.2
    thread.raise(Letsdo::Stopped)
    join_stopped(thread, stderr)
  ensure
    thread&.kill if thread&.alive?
  end

  def sleeping_paused_loop(gate)
    make_loop(provider: once_provider([{ 'id' => 'TASK-1' }]), wait_seconds: 0.3,
              run_one: ->(_task) { 0 },
              sleeper: ->(seconds) { sleep(seconds) }, pause_gate: gate)
  end

  def join_stopped(thread, stderr)
    thread.join(5)
    refute thread.alive?, 'Letsdo::Stopped did not interrupt the gate wait'
    assert_includes stderr.string, 'letsdo: stopped'
  end
end

require_relative 'helpers/fake_backend'

# Factory injection: the loop stops the injected backend through the
# generic protocol (terminate_now), not pi-specific calls.
class AgentLoopBackendTerminationTest < AgentLoopTest
  def test_on_signal_terminates_the_injected_backend
    backend = Letsdo::Backends::Fake.new(prompt: 'x', streamer: nil)
    agent = Struct.new(:backend).new(backend)
    loop_obj, = make_loop(provider: -> { [] }, run_one: ->(_task) { 0 },
                          agent: agent)

    error = assert_raises(Letsdo::Stopped) { loop_obj.on_signal(2) }
    assert_instance_of Letsdo::Stopped, error
    assert backend.finished?, 'on_signal must terminate the backend via the protocol'
  end

  def test_on_signal_tolerates_missing_backend
    agent = Struct.new(:backend).new(nil)
    loop_obj, = make_loop(provider: -> { [] }, run_one: ->(_task) { 0 },
                          agent: agent)

    assert_raises(Letsdo::Stopped) { loop_obj.on_signal(2) }
  end
end

# Shared spawn/wait helpers for real-process signal tests.
module AgentLoopSpawnHelpers
  def letsdo_script
    File.expand_path('../bin/letsdo', __dir__)
  end

  def spawn_letsdo(project_root, env: {})
    err_r, err_w = IO.pipe
    pid = Process.spawn(child_env(env), RbConfig.ruby, letsdo_script, 'developer',
                        chdir: project_root, out: File::NULL, err: err_w)
    err_w.close
    [pid, err_r]
  end

  def child_env(env)
    {
      'PATH' => ENV.fetch('PATH', ''),
      'LETSDO_PI_COMMAND' => fake_pi,
      'LETSDO_BACKLOG_COMMAND' => File.expand_path('fixtures/fake_backlog', __dir__),
      'LETSDO_WAIT_SECONDS' => '120'
    }.merge(env)
  end

  def read_stderr_until(err_r, pattern, timeout: 20)
    buffer = +''
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop { return buffer if read_chunk(err_r, buffer, pattern, deadline) }
  end

  def read_chunk(err_r, buffer, pattern, deadline)
    return true if buffer.include?(pattern)

    remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
    assert_operator remaining, :>, 0,
                    "timed out waiting for #{pattern.inspect}; got: #{buffer.inspect}"
    return false unless IO.select([err_r], nil, nil, 0.2)

    append_nonblock(err_r, buffer)
    false
  end

  def append_nonblock(err_r, buffer)
    buffer << err_r.read_nonblock(4096)
  rescue IO::WaitReadable, EOFError, Errno::EPIPE
    nil
  end

  def drain_stderr(err_r, buffer)
    loop { buffer << err_r.read_nonblock(4096) }
  rescue IO::WaitReadable, EOFError, Errno::EPIPE, Errno::EBADF
    buffer
  end

  def assert_exit_within(pid, expected: 0, timeout: 15)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    status = wait_status(pid, deadline, timeout)
    assert_equal expected, status.exitstatus
  end

  def wait_status(pid, deadline, timeout)
    loop do
      _wpid, status = Process.waitpid2(pid, Process::WNOHANG)
      return status if status

      assert_operator deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC), :>, 0,
                      "child did not exit within #{timeout}s"
      sleep 0.05
    end
  end

  def terminate_leftover(err_r, pid)
    kill_pid(pid)
    close_pipe(err_r)
  end

  def kill_pid(pid)
    Process.kill('KILL', pid)
    Process.waitpid(pid)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def close_pipe(err_r)
    err_r.close unless err_r.closed?
  rescue IOError
    nil
  end

  def with_spawned_letsdo(env)
    with_project('developer' => 'You are a developer.') do |root|
      pid, err_r = spawn_letsdo(root, env: env)
      yield pid, err_r
    ensure
      terminate_leftover(err_r, pid) if err_r && pid
    end
  end

  def stop_after(pid, err_r, pattern, signal)
    stderr = read_stderr_until(err_r, pattern)
    Process.kill(signal, pid)
    assert_exit_within(pid)
    stderr = drain_stderr(err_r, stderr)
    err_r.close
    stderr
  end

  def mid_run_env
    { 'FAKE_BACKLOG_SCENARIO' => 'open', 'FAKE_BACKLOG_COUNT' => '1', 'FAKE_PI_SLEEP' => '300' }
  end
end

# Real-process signal handling: spawn bin/letsdo, send signals, assert exit.
class AgentLoopSignalTest < AgentLoopTest
  include AgentLoopSpawnHelpers

  def test_sigterm_stops_the_loop_during_an_agent_run
    stderr = nil
    with_spawned_letsdo(mid_run_env) do |pid, err_r|
      stderr = stop_after(pid, err_r, 'letsdo: running developer for TASK-1', 'TERM')
    end
    assert_includes stderr, 'letsdo: running developer for TASK-1'
    assert_includes stderr, 'letsdo: stopped'
  end

  def test_sigterm_stops_the_loop_while_waiting_fast
    with_spawned_letsdo({ 'FAKE_BACKLOG_SCENARIO' => 'empty' }) do |pid, err_r|
      read_stderr_until(err_r, 'letsdo: no open tasks for developer')
      elapsed, stderr = term_while_waiting(pid, err_r)
      assert_operator elapsed, :<, 5, "stop in wait mode took #{elapsed.round(2)}s"
      assert_includes stderr, 'letsdo: stopped'
    end
  end

  def term_while_waiting(pid, err_r)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Process.kill('TERM', pid)
    assert_exit_within(pid, timeout: 8)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    stderr = drain_stderr(err_r, +'')
    err_r.close
    [elapsed, stderr]
  end

  def test_sigint_exits_cleanly
    with_spawned_letsdo({ 'FAKE_BACKLOG_SCENARIO' => 'empty' }) do |pid, err_r|
      read_stderr_until(err_r, 'letsdo: no open tasks for developer')
      Process.kill('INT', pid)
      assert_exit_within(pid)
      err_r.close
    end
  end

  def test_sighup_stops_the_loop_like_other_signals
    stderr = nil
    with_spawned_letsdo(mid_run_env) do |pid, err_r|
      stderr = stop_after(pid, err_r, 'letsdo: running developer for TASK-1', 'HUP')
    end
    assert_includes stderr, 'letsdo: stopped'
  end
end

# Quit-while-paused: SIGSTOP the pi group, then SIGTERM the loop.
class AgentLoopPausedSignalTest < AgentLoopSignalTest
  def stopped?(pid)
    File.read("/proc/#{pid}/status").match?(/^State:\s+T\b/)
  rescue Errno::ENOENT, Errno::EACCES
    false
  end

  def wait_stopped_proc(pid, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until stopped?(pid)
      flunk "pi (pid #{pid}) did not stop within #{timeout}s" if overdue?(deadline)
      sleep 0.01
    end
  end

  def test_sigterm_stops_a_paused_pi_promptly
    ready_file = File.join(Dir.mktmpdir('letsdo-ready'), 'ready')
    env = mid_run_env.merge('FAKE_PI_READY_FILE' => ready_file)
    with_spawned_letsdo(env) do |pid, err_r|
      read_stderr_until(err_r, 'letsdo: running developer for TASK-1')
      freeze_then_term(pid, err_r, ready_file)
    end
  end

  def freeze_then_term(pid, err_r, ready_file)
    freeze_pi(ready_file)
    elapsed = term_and_wait(pid)
    assert_operator elapsed, :<, 3.0, "stop while paused took #{elapsed.round(2)}s"
    stderr = drain_stderr(err_r, +'')
    err_r.close
    assert_includes stderr, 'letsdo: stopped'
  end

  def freeze_pi(ready_file)
    pi_pid = wait_for_ready_file(ready_file, timeout: 10)
    Process.kill('STOP', -pi_pid)
    wait_stopped_proc(pi_pid)
  end

  def term_and_wait(pid)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    Process.kill('TERM', pid)
    assert_exit_within(pid, timeout: 8)
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end
end

# A fake watcher standing in for Letsdo::Watcher: records each idle wait and
# runs an optional block in place of the real blocking wait.
class AgentLoopRecordingWatcher
  attr_reader :waits

  def initialize(&on_wait)
    @waits = []
    @on_wait = on_wait
  end

  def wait(seconds)
    @waits << seconds
    @on_wait&.call(seconds)
    :timeout
  end

  def close; end
end

# Watcher + sleeper coexistence (TASK-84): an explicitly injected sleeper is
# honored and never overridden by the watcher idle path.
class AgentLoopWatcherTest < AgentLoopTest
  def build_watcher_loop(watcher:, sleeper: nil, **opts)
    Letsdo::AgentLoop.new(
      name: 'developer', handle: '@developer', watcher: watcher,
      run_one: opts[:run_one] || ->(_task) { 0 },
      task_provider: opts.fetch(:provider, -> { [] }),
      wait_seconds: opts.fetch(:wait_seconds, 0.5),
      sleeper: sleeper, stderr: StringIO.new
    )
  end

  def test_injected_sleeper_wins_over_the_watcher
    watcher = AgentLoopRecordingWatcher.new
    sleeper_calls = []
    sleeper = lambda do |_seconds|
      sleeper_calls << :slept
      throw Letsdo::AgentLoop::STOP
    end
    loop_obj = build_watcher_loop(watcher: watcher, sleeper: sleeper)

    loop_obj.run

    assert_equal [:slept], sleeper_calls
    assert_empty watcher.waits, 'watcher idle path must not override the injected sleeper'
  end

  def test_watcher_provides_the_idle_wait_without_a_sleeper
    watcher = AgentLoopRecordingWatcher.new { throw Letsdo::AgentLoop::STOP }
    loop_obj = build_watcher_loop(watcher: watcher, wait_seconds: 1.5)

    loop_obj.run

    assert_equal [1.5], watcher.waits
  end
end

# Retry behavior (TASK-68): backoff, give-up, cooldown skip, and
# fresh-session reset.
class AgentLoopRetryTest < AgentLoopTest
  def retry_run(base:, exit_code:, max_sleeps:, max_retries: 3, provider: nil)
    policy = retry_policy(base, max_retries)
    err = StringIO.new
    runs = []
    loop_obj, = make_loop(provider: provider || always_provider([{ 'id' => 'TASK-1' }]),
                          run_one: counting_runner(runs, exit_code),
                          wait_seconds: 0, sleeper: counting_sleeper(max_sleeps: max_sleeps),
                          stderr: err, retry_policy: policy)
    loop_obj.run
    [runs, policy, err]
  end

  def retry_policy(base, max_retries)
    Letsdo::RetryPolicy.new(base: base, cap: 300, max_retries: max_retries,
                            clock: -> { 1000 })
  end

  def test_give_up_after_max_retries_stops_task_runs
    runs, policy, err = retry_run(base: 0, exit_code: 1, max_sleeps: 1,
                                  max_retries: 3)

    assert_equal 3, runs.length
    assert_equal 3, policy.failures('TASK-1')
    assert_includes err.string,
                    'letsdo: giving up on TASK-1 after 3 failed runs - ' \
                    'task stays open, next session will retry it'
  end

  def test_cooldown_skip_does_not_re_record_failure
    runs, policy, = retry_run(base: 10, exit_code: 1, max_sleeps: 2, max_retries: 5)

    assert_equal 1, runs.length, 'task must run only once before cooldown holds it'
    assert_equal 1, policy.failures('TASK-1')
  end

  def test_task_absent_clears_retry_state
    calls = 0
    provider = -> { (calls += 1) == 1 ? [Letsdo::Providers::Task.new(id: 'TASK-1')] : [] }
    runs, policy, = retry_run(base: 10, exit_code: 1, max_sleeps: 2, max_retries: 5,
                              provider: provider)

    assert_equal 1, runs.length
    assert_equal 0, policy.failures('TASK-1'), 'absent task must clear retry state'
  end

  def test_exit_zero_with_task_still_open_counts_as_failure
    runs, policy, = retry_run(base: 0, exit_code: 0, max_sleeps: 1, max_retries: 2)

    assert_equal 2, runs.length
    assert_equal 2, policy.failures('TASK-1')
  end
end
