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
end