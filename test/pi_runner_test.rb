# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require "tempfile"

class PiRunnerTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
    @streamer = Letsdo::OutputStreamer.new(stdout: @out, stderr: @err)
  end

  # Runs the fake pi with the given prompt and flags.
  def run_pi(prompt:, flags: [], scenario: nil)
    runner = Letsdo::PiRunner.new(prompt: prompt, flags: flags, streamer: @streamer, command: fake_pi)
    with_scenario(scenario) { runner.run }
  end

  # Sets FAKE_PI_SCENARIO for the duration of the run and removes it after.
  def with_scenario(scenario)
    old = ENV["FAKE_PI_SCENARIO"]
    ENV["FAKE_PI_SCENARIO"] = scenario if scenario
    yield
  ensure
    ENV["FAKE_PI_SCENARIO"] = old
  end

  def test_runs_pi_with_mode_json_flags_and_prompt_in_argv
    Tempfile.create("fake_pi_argv") do |file|
      old = ENV["FAKE_PI_ARGV_FILE"]
      ENV["FAKE_PI_ARGV_FILE"] = file.path
      begin
        run_pi(prompt: "You are an agent", flags: ["--model", "m"])
      ensure
        ENV["FAKE_PI_ARGV_FILE"] = old
      end

      argv = File.read(file.path)
      # Read exactly the ARGV the fake pi received.
      assert_includes argv, "--mode|json|--model|m|You are an agent"
    end
  end

  def test_exit_code_zero
    assert_equal 0, run_pi(prompt: "You are an agent")
  end

  def test_exit_code_propagated
    old = ENV["FAKE_PI_EXIT"]
    ENV["FAKE_PI_EXIT"] = "7"
    begin
      assert_equal 7, run_pi(prompt: "You are an agent")
    ensure
      ENV["FAKE_PI_EXIT"] = old
    end
  end

  def test_output_assembled_from_text_delta
    run_pi(prompt: "You are an agent")

    # A non-JSON line and the other_event in the fake pi stream are ignored;
    # only text_delta reaches stdout.
    assert_equal "Hello, world!\n", @out.string
  end

  def test_empty_text_delta_ignored
    run_pi(prompt: "You are an agent")

    assert_equal "Hello, world!\n", @out.string
  end

  def test_tool_header_shows_name_and_command
    run_pi(prompt: "You are an agent")

    # Call header: time prefix, tool name and the bash command text.
    assert_match(/\A\d{2}:\d{2}:\d{2} ⚙ bash: ls -la\n/, @err.string)
    assert_includes @err.string, "⚙ bash: ls -la"
    assert_equal "Hello, world!\n", @out.string
  end

  def test_tool_completion_has_time_prefix_and_elapsed
    run_pi(prompt: "You are an agent")

    # Completion: time prefix, verdict, name and duration.
    assert_match(/\n\d{2}:\d{2}:\d{2} ✓ bash: done \(\d+(\.\d+)?s\)\n\z/, @err.string)
  end

  def test_tool_result_goes_to_stderr
    run_pi(prompt: "You are an agent")

    # Command output — to stderr, indented, without an error mark.
    assert_includes @err.string, "  total 8"
    assert_includes @err.string, "  drwxr-xr-x  root root"
    refute_includes @err.string, "✖ Error:"
  end

  def test_tool_error_is_marked
    run_pi(prompt: "You are an agent", scenario: "error")

    assert_includes @err.string, "⚙ bash: ls /nonexistent"
    assert_includes @err.string, "✖ Error:"
    assert_includes @err.string, "Command exited with code 2"
  end

  def test_big_tool_result_is_truncated_with_note
    run_pi(prompt: "You are an agent", scenario: "big")

    assert_includes @err.string, "… [output truncated:"
    # The first output lines are in place.
    assert_includes @err.string, "  line 001: xyz"
  end

  def test_toolcall_start_without_execution_falls_back_to_name_only
    run_pi(prompt: "You are an agent", scenario: "stub")

    # No tool_execution_* — a "⚙ name" placeholder is printed on completion.
    assert_includes @err.string, "⚙ bash"
    refute_includes @err.string, "⚙ bash:"
  end

  def test_terminate_stops_a_running_pi
    runner = Letsdo::PiRunner.new(prompt: "You are an agent", streamer: @streamer, command: fake_pi)
    old_sleep = ENV["FAKE_PI_SLEEP"]
    ENV["FAKE_PI_SLEEP"] = "300"
    result = nil
    thread = Thread.new { result = runner.run }
    begin
      sleep 0.3
      runner.terminate
      thread.join(10)
      refute thread.alive?, "terminate did not stop the run"
      # The fake pi was killed by SIGTERM → 128 + 15.
      assert_equal 143, result
    ensure
      ENV["FAKE_PI_SLEEP"] = old_sleep
    end
  end

  def test_terminate_when_run_finished_is_a_noop
    runner = Letsdo::PiRunner.new(prompt: "You are an agent", streamer: @streamer, command: fake_pi)
    assert_equal 0, runner.run
    refute_nil runner.terminate
  end

  # Whether the monotonic deadline has passed (used by the wait helpers
  # below).
  def overdue?(deadline)
    Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  end

  # Waits for the fake pi to write its readiness file (it does so right
  # before the final sleep, when the event stream is already written).
  # Returns the child pid. Pausing only a fully-booted pi makes the
  # stop/resume deterministic: SIGSTOP during the exec/bootstrap window is
  # a kernel-level race.
  def wait_for_ready(ready_file, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return File.read(ready_file).to_i if File.exist?(ready_file)

      flunk "fake pi did not become ready within #{timeout}s" if overdue?(deadline)
      sleep 0.01
    end
  end

  # Waits for the child to enter the stopped state (WUNTRACED reports it
  # without reaping) and returns its Process::Status. Hang-guarded: the
  # blocking wait runs in a helper thread with a join timeout.
  def wait_stopped(pid, timeout: 5)
    stopped = []
    waiter = Thread.new { stopped << Process.waitpid2(pid, Process::WUNTRACED) }
    flunk "pi (pid #{pid}) did not stop within #{timeout}s" unless waiter.join(timeout)
    stopped.first.last
  end

  # Runs the fake pi in a background thread and returns [runner, thread,
  # result_box, ready_file, old_sleep]; the caller controls
  # pause/resume/terminate from the main thread, exactly like the input
  # thread would in real use. result_box is a mutable Hash the worker
  # writes into — reading it from the main thread always sees the latest
  # value. ready_file receives the child pid once it is fully booted.
  def run_pi_background(sleep_seconds)
    runner = Letsdo::PiRunner.new(prompt: "You are an agent", streamer: @streamer, command: fake_pi)
    old_sleep = ENV["FAKE_PI_SLEEP"]
    ENV["FAKE_PI_SLEEP"] = sleep_seconds.to_s
    ready_file = File.join(Dir.mktmpdir("letsdo-ready"), "ready")
    old_ready = ENV["FAKE_PI_READY_FILE"]
    ENV["FAKE_PI_READY_FILE"] = ready_file
    result_box = { result: nil }
    thread = Thread.new { result_box[:result] = runner.run }
    [runner, thread, result_box, ready_file, old_sleep, old_ready]
  end

  def test_pause_stops_the_pi_group_mid_run
    runner, thread, result_box, ready_file, old_sleep, old_ready = run_pi_background(300)
    begin
      pid = wait_for_ready(ready_file)
      runner.pause

      # The child enters the stopped state (SIGSTOP, observed without
      # reaping) and the run does not progress while frozen.
      status = wait_stopped(pid)
      assert status.stopped?, "pi should be stopped, got #{status.inspect}"
      assert_equal 19, status.stopsig, "stopped by SIGSTOP"
      sleep 0.1
      assert_nil result_box[:result], "run must not finish while paused"
      assert thread.alive?
    ensure
      ENV["FAKE_PI_SLEEP"] = old_sleep
      ENV["FAKE_PI_READY_FILE"] = old_ready
      runner.terminate
      thread.join(5)
    end
  end

  def test_resume_continues_the_run_with_unchanged_exit_code
    # Short sleep: after resume the fake pi completes on its own.
    runner, thread, result_box, ready_file, old_sleep, old_ready = run_pi_background(3)
    begin
      pid = wait_for_ready(ready_file)
      runner.pause
      wait_stopped(pid)

      runner.resume
      thread.join(10)
      refute thread.alive?, "resume did not let the run finish"
      assert_equal 0, result_box[:result], "exit code must be unchanged after pause/resume"
    ensure
      ENV["FAKE_PI_SLEEP"] = old_sleep
      ENV["FAKE_PI_READY_FILE"] = old_ready
      runner.terminate
      thread.join(5)
    end
  end

  def test_pause_and_resume_are_noops_without_a_run
    runner = Letsdo::PiRunner.new(prompt: "You are an agent", streamer: @streamer, command: fake_pi)
    assert_nil runner.pause
    assert_nil runner.resume
    assert_equal 0, runner.run
    # After the run finished @pid is cleared — still no-ops.
    assert_nil runner.pause
    assert_nil runner.resume
  end

  def test_pause_and_resume_swallow_esrch_for_a_dead_group
    runner = Letsdo::PiRunner.new(prompt: "You are an agent", streamer: @streamer, command: fake_pi)
    dead_pid = Process.spawn("true")
    Process.wait(dead_pid)
    runner.instance_variable_set(:@pid, dead_pid)

    assert_nil runner.pause
    assert_nil runner.resume
  rescue Errno::ESRCH, Errno::EPERM
    flunk "pause/resume must swallow ESRCH/EPERM like send_signal"
  end

  def test_terminate_kills_a_paused_pi_promptly
    runner, thread, result_box, ready_file, old_sleep, old_ready = run_pi_background(300)
    begin
      pid = wait_for_ready(ready_file)
      runner.pause
      wait_stopped(pid)

      # SIGCONT-before-SIGTERM: the frozen child must not stall for the
      # whole 3s grace period.
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      runner.terminate
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      assert_operator elapsed, :<, 1.0, "terminate on a paused pi took #{elapsed.round(2)}s"

      thread.join(10)
      refute thread.alive?, "terminate did not stop the paused run"
      assert_equal 143, result_box[:result], "killed by SIGTERM → 128 + 15"
    ensure
      ENV["FAKE_PI_SLEEP"] = old_sleep
      ENV["FAKE_PI_READY_FILE"] = old_ready
      runner.terminate
      thread.join(5)
    end
  end
end
