# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

# Session tests drive the full controller with injected components only:
# a pipe keyboard (real Tui::Input decoding escape bytes), a StringIO
# terminal with a fixed size provider, a real LogBuffer and Metrics with a
# controllable clock, and a scripted orchestrator block. No real TTY.
class TuiSessionTest < Minitest::Test
  HOME = "\e[1;1H"
  ENTER_ALT = "\e[?1049h"
  LEAVE_ALT = "\e[?1049l"

  def setup
    @terminal_io = StringIO.new
    @clock = 0.0
    @log = Letsdo::Tui::LogBuffer.new
    @metrics = Letsdo::Tui::Metrics.new(name: "developer", handle: "@developer",
                                        clock: -> { @clock })
  end

  def terminal
    Letsdo::Tui::Terminal.new(stream: @terminal_io, size_provider: -> { [8, 60] })
  end

  def input_for(keys)
    reader, writer = IO.pipe
    writer.write(keys)
    writer.close
    Letsdo::Tui::Input.new(stdin: reader, poll_timeout: 0)
  end

  # Runs a session over the given key script and work block.
  def run_session(keys, refresh: nil, &work)
    session = Letsdo::Tui::Session.new(
      name: "developer", handle: "@developer", log: @log, metrics: @metrics,
      terminal: terminal, input: input_for(keys), refresh: refresh,
      wait_seconds: 10, clock: -> { @clock }
    )
    session.run(&work)
  end

  # The rendered frames (terminal writes between the HOME prefixes).
  # Leave-screen bytes are appended after the last frame, so they are
  # stripped first; otherwise split(HOME) would drop that last frame.
  def frames
    body = @terminal_io.string.sub(/#{Regexp.escape(LEAVE_ALT)}\z/, "")
    parts = body.split(HOME)
    parts.shift # enter sequence, no HOME before the first frame
    parts
  end

  def seed_lines(count)
    @log.write((0...count).map { |i| "line #{i}" }.join("\n") + "\n")
  end

  def test_quit_restores_the_terminal_and_returns_zero
    result = run_session("q") { sleep 0.5; :not_reached }

    assert_equal 0, result
    assert_includes @terminal_io.string, ENTER_ALT
    assert_includes @terminal_io.string, LEAVE_ALT
  end

  def test_initial_frame_shows_header_and_log
    seed_lines(3)
    @metrics.provider_result(76)
    @metrics.run_started("TASK-42")
    @clock = 30.0
    run_session("q") { sleep 0.5; 0 }

    first = frames.first
    assert_includes first, "letsdo · developer (@developer)"
    assert_includes first, "session 00:00:30"
    assert_includes first, "done 0"
    assert_includes first, "left 76"
    assert_includes first, "task TASK-42"
    assert_includes first, "line 0"
    assert_includes first, "↑/↓ PgUp/PgDn scroll · p pause · r refresh · q quit"
  end

  def test_pause_shows_paused_overlay
    run_session("pq") { sleep 0.5; 0 }

    refute_includes frames.first, "PAUSED"
    assert_includes frames.last, "PAUSED"
  end

  def test_scroll_up_leaves_follow_mode
    seed_lines(30)
    run_session("\e[Aq") { sleep 0.5; 0 }

    last = frames.last
    assert_includes last, "line 26"
    assert_includes last, "line 28"
    refute_includes last, "line 29"
  end

  def test_end_resticks_to_the_bottom
    seed_lines(30)
    run_session("\e[A\e[Fq") { sleep 0.5; 0 }

    last = frames.last
    assert_includes last, "line 29"
  end

  def test_home_scrolls_to_the_top
    seed_lines(30)
    run_session("\e[Hq") { sleep 0.5; 0 }

    last = frames.last
    assert_includes last, "line 0"
    refute_includes last, "line 29"
  end

  def test_new_log_lines_re_stick_the_follow_view
    seed_lines(3)
    run_session("") do
      sleep 0.05
      @log.write("line 3\n")
      sleep 0.3
      0
    end

    last = frames.last
    assert_includes last, "line 3"
  end

  def test_refresh_collects_the_provider_count
    @metrics.provider_result(2)
    refresh = -> { 5 }
    run_session("rq", refresh: refresh) { sleep 0.5; 0 }

    assert_includes frames.last, "left 5"
    assert_equal 5, @metrics.snapshot.left
  end

  def test_work_result_is_returned_when_not_stopped
    result = run_session("") { 7 }

    assert_equal 7, result
    assert_includes @terminal_io.string, LEAVE_ALT
  end

  def test_terminal_is_restored_even_when_the_work_raises
    session = Letsdo::Tui::Session.new(
      name: "developer", handle: "@developer", log: @log, metrics: @metrics,
      terminal: terminal, input: input_for(""), wait_seconds: 10, clock: -> { @clock }
    )

    assert_raises(RuntimeError) do
      session.run { raise "boom" }
    end
    assert_includes @terminal_io.string, LEAVE_ALT
  end
end