# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'rbconfig'

class TuiTerminalTest < Minitest::Test
  def setup
    @stream = StringIO.new
    @terminal = Letsdo::Tui::Terminal.new(stream: @stream, size_provider: -> { [24, 80] })
  end

  def test_enter_switches_to_the_alternate_screen_and_hides_cursor
    @terminal.enter

    assert_includes @stream.string, "\e[?1049h"
    assert_includes @stream.string, TTY::Cursor.hide
  end

  def test_leave_shows_cursor_and_returns_to_the_main_screen
    @terminal.leave

    assert_includes @stream.string, TTY::Cursor.show
    assert_includes @stream.string, "\e[?1049l"
  end

  def test_render_moves_cursor_home_then_writes_the_frame
    @terminal.render('frame')

    assert_equal "\e[1;1Hframe", @stream.string
  end

  # TASK-82 regression: the frame must reach the terminal with CRLF row
  # separators. While stdin is held in io-console raw mode (the whole TUI
  # session) OPOST is off on the shared tty, so a bare \n never returns the
  # cursor to column 0 and every row after the first wraps — the reported
  # "blank activity pane" (content flashes then clears).
  def test_render_uses_crlf_row_separators
    @terminal.render("head\nbody\ntail")

    assert_equal "\e[1;1Hhead\r\nbody\r\ntail", @stream.string
  end

  def test_render_preserves_a_trailing_line_without_extra_newline
    @terminal.render("one\ntwo")

    refute_includes @stream.string, "two\n"
  end

  def test_size_comes_from_the_provider
    assert_equal [24, 80], @terminal.size
  end

  def test_size_falls_back_when_the_provider_gives_nil
    terminal = Letsdo::Tui::Terminal.new(stream: StringIO.new, size_provider: -> { [nil, nil] })

    assert_equal [24, 80], terminal.size
  end

  # TASK-78 regression: requiring the terminal (and letsdo) must not eagerly
  # load tty-cursor — the constant appears only when the TTY path is taken.
  # A subprocess gives a fresh interpreter, so earlier tests can't have
  # loaded the gem in-process.
  def test_requiring_terminal_does_not_eagerly_load_tty_cursor
    output = ruby_subprocess_output(<<~'RUBY')
      require "letsdo/tui/terminal"
      abort "eagerly loaded tty-cursor" if defined?(TTY::Cursor)
      print "ok"
    RUBY

    assert_equal 'ok', output
  end

  private

  def ruby_subprocess_output(code)
    lib = File.expand_path('../lib', __dir__)
    IO.popen([RbConfig.ruby, '-I', lib, '-e', code], err: %i[child out], &:read)
  end
end
