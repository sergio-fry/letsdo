# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class OutputStreamerTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
    @streamer = Letsdo::OutputStreamer.new(stdout: @out, stderr: @err)
  end

  def test_text_delta_appends_to_stdout
    @streamer.text_delta("Привет, ")
    @streamer.text_delta("мир!")

    assert_equal "Привет, мир!", @out.string
  end

  def test_text_delta_writes_immediately
    @streamer.text_delta("кусок")

    assert_equal "кусок", @out.string
  end

  def test_text_delta_ignores_empty_and_nil
    @streamer.text_delta("")
    @streamer.text_delta(nil)

    assert_empty @out.string
  end

  def test_tool_start_with_bash_command
    @streamer.tool_start("bash", args: { "command" => "ls -la" })

    assert_equal "⚙ bash: ls -la\n", @err.string
    assert_empty @out.string
  end

  def test_tool_start_shows_read_path_and_line_range
    @streamer.tool_start("read", args: { "path" => "lib/letsdo.rb", "offset" => 5, "limit" => 3 })

    assert_equal "⚙ read: lib/letsdo.rb:5-7\n", @err.string
  end

  def test_tool_start_without_args_prints_name_only
    @streamer.tool_start("ls", args: {})

    assert_equal "⚙ ls\n", @err.string
  end

  def test_tool_start_with_nil_args_prints_name_only
    @streamer.tool_start("bash")

    assert_equal "⚙ bash\n", @err.string
  end

  def test_tool_start_unknown_tool_shows_compact_json
    @streamer.tool_start("custom", args: { "from" => "a", "to" => "b" })

    assert_equal "⚙ custom: {\"from\":\"a\",\"to\":\"b\"}\n", @err.string
  end

  def test_tool_start_truncates_long_args
    @streamer.tool_start("bash", args: { "command" => ("a" * 500) })

    line = @err.string
    assert line.start_with?("⚙ bash: ")
    assert line.end_with?("…\n")
    assert_operator line.length, :<, 350
  end

  def test_tool_result_prints_lines_with_indent
    @streamer.tool_result("total 8\nfile0\n")

    assert_equal "  total 8\n  file0\n", @err.string
  end

  def test_tool_result_error_is_marked
    @streamer.tool_result("ls: cannot access '/x': No such file or directory", error: true)

    assert_includes @err.string, "✖ Ошибка: ls: cannot access '/x': No such file or directory"
  end

  def test_tool_result_error_marks_only_first_line
    @streamer.tool_result("ошибка\nподробности", error: true)

    assert_equal "  ✖ Ошибка: ошибка\n  подробности\n", @err.string
  end

  def test_tool_result_ignores_empty
    @streamer.tool_result("")
    @streamer.tool_result(nil)

    assert_empty @err.string
  end

  def test_tool_result_truncates_by_lines_with_note
    text = (1..200).map { |i| "строка #{i}" }.join("\n")
    @streamer.tool_result(text)

    assert_includes @err.string, "  строка 1\n"
    assert_includes @err.string, "… [вывод обрезан: 200 строк,"
    refute_includes @err.string, "строка 150"
  end

  def test_tool_result_truncates_single_long_line
    @streamer.tool_result("a" * 5_000)

    assert_includes @err.string, "… [вывод обрезан: 1 строка,"
    # Лимит символов результата: MAX_RESULT_CHARS + префикс отступа.
    assert_operator @err.string.length, :<, Letsdo::OutputStreamer::MAX_RESULT_CHARS + 200
  end

  def test_tool_result_without_trailing_empty_line
    @streamer.tool_result("первая\n")

    assert_equal "  первая\n", @err.string
  end

  def test_finish_adds_trailing_newline_when_missing
    @streamer.text_delta("ответ без перевода строки")
    @streamer.finish

    assert_equal "ответ без перевода строки\n", @out.string
  end

  def test_finish_does_not_add_second_newline
    @streamer.text_delta("ответ\n")
    @streamer.finish

    assert_equal "ответ\n", @out.string
  end

  def test_finish_is_noop_when_nothing_was_written
    @streamer.finish

    assert_empty @out.string
  end
end