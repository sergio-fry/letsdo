# frozen_string_literal: true

require_relative "test_helper"

class TuiLogBufferTest < Minitest::Test
  def test_write_appends_complete_lines
    log = Letsdo::Tui::LogBuffer.new

    log.write("one\ntwo\n")

    lines, = log.lines
    assert_equal ["one", "two"], lines
  end

  def test_partial_last_line_is_kept
    log = Letsdo::Tui::LogBuffer.new

    log.write("first line done\nagent text in progre")

    lines, = log.lines
    assert_equal ["first line done", "agent text in progre"], lines
  end

  def test_partial_line_merges_across_writes
    log = Letsdo::Tui::LogBuffer.new

    log.write("one")
    log.write(" two")
    log.write("\nthree\n")

    lines, = log.lines
    assert_equal ["one two", "three"], lines
  end

  def test_puts_appends_a_newline
    log = Letsdo::Tui::LogBuffer.new

    log.puts("service line")

    lines, = log.lines
    assert_equal ["service line"], lines
  end

  def test_puts_without_arguments_appends_an_empty_line
    log = Letsdo::Tui::LogBuffer.new

    log.puts

    lines, = log.lines
    assert_equal [""], lines
  end

  def test_empty_writes_are_ignored
    log = Letsdo::Tui::LogBuffer.new
    log.write("")
    log.write(nil)

    lines, = log.lines
    assert_equal [], lines
  end

  def test_caps_lines_and_drops_oldest
    log = Letsdo::Tui::LogBuffer.new(max_lines: 3)

    log.write("a\nb\nc\nd\n")

    lines, = log.lines
    assert_equal ["b", "c", "d"], lines
  end

  def test_divider_marks_a_run_boundary
    log = Letsdo::Tui::LogBuffer.new
    log.write("a\n")

    log.divider
    log.write("b\n")

    lines, = log.lines
    assert_equal ["a", Letsdo::Tui::LogBuffer::DIVIDER, "b"], lines
  end

  def test_divider_is_skipped_when_the_buffer_is_empty
    log = Letsdo::Tui::LogBuffer.new

    log.divider

    lines, = log.lines
    assert_equal [], lines
  end

  def test_version_grows_on_every_write
    log = Letsdo::Tui::LogBuffer.new
    _, version = log.lines

    log.write("a\n")
    _, version_after = log.lines

    assert_operator version_after, :>, version
    assert_equal version_after, log.version
  end

  def test_version_is_stable_when_nothing_changed
    log = Letsdo::Tui::LogBuffer.new
    log.write("a\n")

    _, v1 = log.lines
    _, v2 = log.lines

    assert_equal v1, v2
  end

  def test_flush_is_a_noop
    log = Letsdo::Tui::LogBuffer.new

    assert_same log, log.flush
  end
end