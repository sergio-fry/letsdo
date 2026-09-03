# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class OutputStreamerTest < Minitest::Test
  TIME_PREFIX = /\A\d{2}:\d{2}:\d{2} /.freeze

  def setup
    @out = StringIO.new
    @err = StringIO.new
    @now = Time.local(2026, 9, 3, 14, 5, 3) # 14:05:03
    @streamer = Letsdo::OutputStreamer.new(stdout: @out, stderr: @err, clock: -> { @now })
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

  def test_text_delta_has_no_time_prefix_in_stdout
    @streamer.text_delta("ответ агента")

    assert_equal "ответ агента", @out.string
    assert_empty @err.string
  end

  def test_tool_start_with_bash_command
    @streamer.tool_start("bash", args: { "command" => "ls -la" })

    assert_equal "14:05:03 ⚙ bash: ls -la\n", @err.string
    assert_empty @out.string
  end

  def test_tool_start_shows_read_path_and_line_range
    @streamer.tool_start("read", args: { "path" => "lib/letsdo.rb", "offset" => 5, "limit" => 3 })

    assert_equal "14:05:03 ⚙ read: lib/letsdo.rb:5-7\n", @err.string
  end

  def test_tool_start_without_args_prints_name_only
    @streamer.tool_start("ls", args: {})

    assert_equal "14:05:03 ⚙ ls\n", @err.string
  end

  def test_tool_start_with_nil_args_prints_name_only
    @streamer.tool_start("bash")

    assert_equal "14:05:03 ⚙ bash\n", @err.string
  end

  def test_tool_start_unknown_tool_shows_compact_json
    @streamer.tool_start("custom", args: { "from" => "a", "to" => "b" })

    assert_equal "14:05:03 ⚙ custom: {\"from\":\"a\",\"to\":\"b\"}\n", @err.string
  end

  def test_tool_start_truncates_long_args
    @streamer.tool_start("bash", args: { "command" => ("a" * 500) })

    line = @err.string
    assert line.start_with?("14:05:03 ⚙ bash: ")
    assert line.end_with?("…\n")
    assert_operator line.length, :<, 350
  end

  def test_every_action_line_has_hh_mm_ss_prefix
    @streamer.tool_start("bash", args: { "command" => "ls" })
    @now += 7
    @streamer.tool_start("read", args: { "path" => "a.rb" })
    @now += 3
    @streamer.tool_result("bash", "total 8\n")

    lines = @err.string.lines
    # Единый формат префикса у всех строк-действий: запуск и завершение.
    assert_equal 4, lines.length
    assert_match TIME_PREFIX, lines[0] # запуск 1
    assert_match TIME_PREFIX, lines[1] # запуск 2
    assert_match TIME_PREFIX, lines[3] # завершение
    assert_match /\A14:05:03 ⚙/, lines[0]
    assert_match /\A14:05:10 ⚙/, lines[1]
    assert_match /\A14:05:13 ✓/, lines[3]
    # Строки результата (данные) префикса времени не получают.
    refute_match TIME_PREFIX, lines[2]
    assert_equal "  total 8\n", lines[2]
  end

  def test_tool_flow_prints_block_then_completion_with_elapsed
    @streamer.tool_start("bash", args: { "command" => "ls -la" })
    @now += 7
    @streamer.tool_result("bash", "total 8\nfile0\n")

    assert_equal "14:05:03 ⚙ bash: ls -la\n" \
                 "  total 8\n" \
                 "  file0\n" \
                 "14:05:10 ✓ bash: завершено (7.0s)\n", @err.string
  end

  def test_tool_result_elapsed_rounds_seconds_over_ten
    @streamer.tool_start("bash")
    @now += 42
    @streamer.tool_result("bash", "ok\n")

    assert_includes @err.string, "14:05:45 ✓ bash: завершено (42s)\n"
  end

  def test_tool_result_error_is_marked
    @streamer.tool_result("bash", "ls: cannot access '/x': No such file or directory", error: true)

    assert_includes @err.string, "✖ Ошибка: ls: cannot access '/x': No such file or directory"
    assert_includes @err.string, "14:05:03 ✖ bash: ошибка\n"
  end

  def test_tool_result_error_marks_only_first_line
    @streamer.tool_result("bash", "ошибка\nподробности", error: true)

    assert_equal "  ✖ Ошибка: ошибка\n" \
                 "  подробности\n" \
                 "14:05:03 ✖ bash: ошибка\n", @err.string
  end

  def test_tool_result_empty_still_prints_completion
    @streamer.tool_result("bash", "")
    @streamer.tool_result("bash", nil)

    assert_equal "14:05:03 ✓ bash: завершено\n" \
                 "14:05:03 ✓ bash: завершено\n", @err.string
  end

  def test_tool_result_without_known_start_omits_elapsed
    @streamer.tool_result("bash", "ок\n")

    assert_equal "  ок\n" \
                 "14:05:03 ✓ bash: завершено\n", @err.string
  end

  def test_tool_result_truncates_by_lines_with_note
    text = (1..200).map { |i| "строка #{i}" }.join("\n")
    @streamer.tool_result("bash", text)

    assert_includes @err.string, "  строка 1\n"
    assert_includes @err.string, "… [вывод обрезан: 200 строк,"
    refute_includes @err.string, "строка 150"
    assert_includes @err.string, "✓ bash: завершено\n"
  end

  def test_tool_result_truncates_single_long_line
    @streamer.tool_result("bash", "a" * 5_000)

    assert_includes @err.string, "… [вывод обрезан: 1 строка,"
    # Лимит символов результата: MAX_RESULT_CHARS + префиксы строк.
    assert_operator @err.string.length, :<, Letsdo::OutputStreamer::MAX_RESULT_CHARS + 200
  end

  def test_tool_result_without_trailing_empty_line
    @streamer.tool_result("bash", "первая\n")

    assert_equal "  первая\n" \
                 "14:05:03 ✓ bash: завершено\n", @err.string
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