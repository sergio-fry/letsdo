# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'tempfile'

# PiRunner tests drive the real runner against test/fixtures/fake_pi.
# The base class holds the harness; each concern below is its own class
# so every class stays within the default length limits.
class PiRunnerTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
    @streamer = Letsdo::OutputStreamer.new(stdout: @out, stderr: @err)
  end

  def run_pi(prompt:, flags: [], scenario: nil)
    runner = Letsdo::PiRunner.new(prompt: prompt, flags: flags, streamer: @streamer,
                                  command: fake_pi)
    with_env(scenario_env(scenario)) { runner.run }
  end

  def scenario_env(scenario)
    scenario ? { 'FAKE_PI_SCENARIO' => scenario } : {}
  end

  def new_runner
    Letsdo::PiRunner.new(prompt: 'You are an agent', streamer: @streamer, command: fake_pi)
  end

  # Waits for the child to enter the stopped state (WUNTRACED reports it
  # without reaping) and returns its Process::Status.
  def wait_stopped(pid, timeout: 5)
    stopped = []
    waiter = Thread.new { stopped << Process.waitpid2(pid, Process::WUNTRACED) }
    flunk "pi (pid #{pid}) did not stop within #{timeout}s" unless waiter.join(timeout)
    stopped.first.last
  end
end

# Event-stream behaviour: argv, exit codes, text, tools.
class PiRunnerStreamTest < PiRunnerTest
  def test_runs_pi_with_mode_json_flags_and_prompt_in_argv
    with_argv_capture do |path|
      run_pi(prompt: 'You are an agent', flags: ['--model', 'm'])
      argv = File.read(path)
      assert_includes argv, '--mode|json|--model|m|You are an agent'
    end
  end

  def with_argv_capture
    Tempfile.create('fake_pi_argv') do |file|
      with_env('FAKE_PI_ARGV_FILE' => file.path) { yield file.path }
    end
  end

  def test_exit_code_zero
    assert_equal 0, run_pi(prompt: 'You are an agent')
  end

  def test_exit_code_propagated
    with_env('FAKE_PI_EXIT' => '7') do
      assert_equal 7, run_pi(prompt: 'You are an agent')
    end
  end

  def test_output_assembled_from_text_delta
    run_pi(prompt: 'You are an agent')

    assert_equal "Hello, world!\n", @out.string
  end

  def test_empty_text_delta_ignored
    run_pi(prompt: 'You are an agent')

    assert_equal "Hello, world!\n", @out.string
  end

  def test_tool_header_shows_name_and_command
    run_pi(prompt: 'You are an agent')

    assert_match(/\A\d{2}:\d{2}:\d{2} ⚙ bash: ls -la\n/, @err.string)
    assert_includes @err.string, '⚙ bash: ls -la'
    assert_equal "Hello, world!\n", @out.string
  end

  def test_tool_completion_has_time_prefix_and_elapsed
    run_pi(prompt: 'You are an agent')

    assert_match(/\n\d{2}:\d{2}:\d{2} ✓ bash: done \(\d+(\.\d+)?s\)\n\z/, @err.string)
  end

  def test_tool_result_body_is_not_printed
    run_pi(prompt: 'You are an agent')

    refute_includes @err.string, '  total 8'
    refute_includes @err.string, '  drwxr-xr-x  root root'
    refute_includes @err.string, '✖ Error:'
    assert_includes @err.string, '✓ bash: done'
  end

  def test_tool_error_shows_error_completion_only
    run_pi(prompt: 'You are an agent', scenario: 'error')

    assert_includes @err.string, '⚙ bash: ls /nonexistent'
    assert_includes @err.string, '✖ bash: error'
    refute_includes @err.string, '✖ Error:'
    refute_includes @err.string, 'Command exited with code 2'
  end

  def test_big_tool_result_body_is_not_printed
    run_pi(prompt: 'You are an agent', scenario: 'big')

    refute_includes @err.string, '… [output truncated:'
    refute_includes @err.string, '  line 001: xyz'
    assert_includes @err.string, '✓ bash: done'
  end

  def test_toolcall_start_without_execution_falls_back_to_name_only
    run_pi(prompt: 'You are an agent', scenario: 'stub')

    assert_includes @err.string, '⚙ bash'
    refute_includes @err.string, '⚙ bash:'
  end
end

# Process control: terminate, pause, resume, ESRCH no-ops.
class PiRunnerControlTest < PiRunnerTest
  def test_terminate_stops_a_running_pi
    runner = new_runner
    result = nil
    with_env('FAKE_PI_SLEEP' => '300') do
      thread = Thread.new { result = runner.run }
      sleep 0.3
      runner.terminate
      thread.join(10)
      refute thread.alive?, 'terminate did not stop the run'
      assert_equal 143, result
    end
  end

  def test_terminate_when_run_finished_is_a_noop
    runner = new_runner

    assert_equal 0, runner.run
    refute_nil runner.terminate
  end

  def test_pause_stops_the_pi_group_mid_run
    with_background_pi(300) do |runner, thread, result_box, pid|
      runner.pause
      status = wait_stopped(pid)
      assert_stopped_by_sigstop(status)
      sleep 0.1
      assert_nil result_box[:result], 'run must not finish while paused'
      assert thread.alive?
    end
  end

  def assert_stopped_by_sigstop(status)
    assert status.stopped?, "pi should be stopped, got #{status.inspect}"
    assert_equal 19, status.stopsig, 'stopped by SIGSTOP'
  end

  def test_resume_continues_the_run_with_unchanged_exit_code
    with_background_pi(3) do |runner, thread, result_box, pid|
      runner.pause
      wait_stopped(pid)
      runner.resume
      thread.join(10)
      refute thread.alive?, 'resume did not let the run finish'
      assert_equal 0, result_box[:result], 'exit code must be unchanged after pause/resume'
    end
  end

  def test_pause_and_resume_are_noops_without_a_run
    runner = new_runner

    assert_nil runner.pause
    assert_nil runner.resume
    assert_equal 0, runner.run
    assert_nil runner.pause
    assert_nil runner.resume
  end

  def test_pause_and_resume_swallow_esrch_for_a_dead_group
    runner = new_runner
    dead_pid = Process.spawn('true')
    Process.wait(dead_pid)
    runner.instance_variable_set(:@pid, dead_pid)

    assert_nil runner.pause
    assert_nil runner.resume
  rescue Errno::ESRCH, Errno::EPERM
    flunk 'pause/resume must swallow ESRCH/EPERM like send_signal'
  end

  def test_terminate_kills_a_paused_pi_promptly
    with_background_pi(300) do |runner, thread, result_box, pid|
      runner.pause
      wait_stopped(pid)
      assert_prompt_terminate(runner)
      thread.join(10)
      refute thread.alive?, 'terminate did not stop the paused run'
      assert_equal 143, result_box[:result], 'killed by SIGTERM → 128 + 15'
    end
  end

  def assert_prompt_terminate(runner)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    runner.terminate
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    assert_operator elapsed, :<, 1.0, "terminate on a paused pi took #{elapsed.round(2)}s"
  end

  def with_background_pi(sleep_seconds)
    ready_file = File.join(Dir.mktmpdir('letsdo-ready'), 'ready')
    ctx = {}
    env = { 'FAKE_PI_SLEEP' => sleep_seconds.to_s, 'FAKE_PI_READY_FILE' => ready_file }
    with_env(env) { run_background_body(ctx, ready_file) { |*args| yield(*args) } }
  ensure
    ctx[:runner]&.terminate
    ctx[:thread]&.join(5)
  end

  def run_background_body(ctx, ready_file)
    result_box = { result: nil }
    ctx[:runner] = new_runner
    ctx[:thread] = Thread.new { result_box[:result] = ctx[:runner].run }
    yield ctx[:runner], ctx[:thread], result_box, wait_for_ready_file(ready_file)
  end
end
