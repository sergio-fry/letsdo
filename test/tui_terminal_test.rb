# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

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
    @terminal.render("frame")

    assert_equal "\e[1;1Hframe", @stream.string
  end

  def test_size_comes_from_the_provider
    assert_equal [24, 80], @terminal.size
  end

  def test_size_falls_back_when_the_provider_gives_nil
    terminal = Letsdo::Tui::Terminal.new(stream: StringIO.new, size_provider: -> { [nil, nil] })

    assert_equal [24, 80], terminal.size
  end
end