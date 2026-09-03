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

  # Запускает фейковый pi с данным промптом и флагами.
  def run_pi(prompt:, flags: [], scenario: nil)
    runner = Letsdo::PiRunner.new(prompt: prompt, flags: flags, streamer: @streamer, command: fake_pi)
    with_scenario(scenario) { runner.run }
  end

  # Выставляет FAKE_PI_SCENARIO на время прогона и убирает после.
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
        run_pi(prompt: "Ты агент", flags: ["--model", "m"])
      ensure
        ENV["FAKE_PI_ARGV_FILE"] = old
      end

      argv = File.read(file.path)
      # Прочитали ровно тот ARGV, что получил фейковый pi.
      assert_includes argv, "--mode|json|--model|m|Ты агент"
    end
  end

  def test_exit_code_zero
    assert_equal 0, run_pi(prompt: "Ты агент")
  end

  def test_exit_code_propagated
    old = ENV["FAKE_PI_EXIT"]
    ENV["FAKE_PI_EXIT"] = "7"
    begin
      assert_equal 7, run_pi(prompt: "Ты агент")
    ensure
      ENV["FAKE_PI_EXIT"] = old
    end
  end

  def test_output_assembled_from_text_delta
    run_pi(prompt: "Ты агент")

    # Не-JSON строка и событие other_event в потоке фейкового pi
    # игнорируются; в stdout попадают только text_delta.
    assert_equal "Привет, мир!\n", @out.string
  end

  def test_empty_text_delta_ignored
    run_pi(prompt: "Ты агент")

    assert_equal "Привет, мир!\n", @out.string
  end

  def test_tool_header_shows_name_and_command
    run_pi(prompt: "Ты агент")

    # Заголовок вызова: имя инструмента и текст команды bash.
    assert_includes @err.string, "⚙ bash: ls -la"
    assert_equal "Привет, мир!\n", @out.string
  end

  def test_tool_result_goes_to_stderr
    run_pi(prompt: "Ты агент")

    # Вывод команды — в stderr, с отступом, без пометки ошибки.
    assert_includes @err.string, "  total 8"
    assert_includes @err.string, "  drwxr-xr-x  root root"
    refute_includes @err.string, "✖ Ошибка:"
  end

  def test_tool_error_is_marked
    run_pi(prompt: "Ты агент", scenario: "error")

    assert_includes @err.string, "⚙ bash: ls /nonexistent"
    assert_includes @err.string, "✖ Ошибка:"
    assert_includes @err.string, "Command exited with code 2"
  end

  def test_big_tool_result_is_truncated_with_note
    run_pi(prompt: "Ты агент", scenario: "big")

    assert_includes @err.string, "… [вывод обрезан:"
    # Первые строки вывода на месте.
    assert_includes @err.string, "  line 001: xyz"
  end

  def test_toolcall_start_without_execution_falls_back_to_name_only
    run_pi(prompt: "Ты агент", scenario: "stub")

    # Нет tool_execution_* — при завершении печатается заглушка «⚙ имя».
    assert_includes @err.string, "⚙ bash"
    refute_includes @err.string, "⚙ bash:"
  end
end