# frozen_string_literal: true

require_relative "test_helper"
require "unicode/display_width"

# The renderer is a pure function: (metrics snapshot, log lines, width,
# height, offset/follow/paused) → framed String. Every test here builds
# inputs directly — no terminal, no IO, no TTY.
class TuiRendererTest < Minitest::Test
  SNAPSHOT = Letsdo::Tui::Metrics::Snapshot

  def snapshot(done: 3, left: 2, session_seconds: 754.0, current_task: "TASK-42",
               current_task_seconds: 201.0)
    SNAPSHOT.new(name: "developer", handle: "@developer", done: done, left: left,
                 session_seconds: session_seconds, current_task: current_task,
                 current_task_seconds: current_task_seconds)
  end

  def render(metrics: nil, lines: [], width: 60, height: 10, offset: 0,
             follow: true, paused: false, wait_seconds: 10.0, **snapshot_attrs)
    metrics ||= snapshot(**snapshot_attrs)
    Letsdo::Tui::Renderer.render(metrics: metrics, lines: lines, width: width,
                                 height: height, offset: offset, follow: follow,
                                 paused: paused, wait_seconds: wait_seconds)
  end

  def test_header_shows_name_handle_and_session_timer
    frame = render(session_seconds: 754.0)

    line = frame.lines[0]
    assert_includes line, "letsdo · developer (@developer)"
    assert_includes line, "session 00:12:34"
  end

  def test_footer_lists_keys
    frame = render

    assert_includes frame.lines[-1], "↑/↓ PgUp/PgDn scroll · p pause · r refresh · q quit"
  end

  def test_running_state_line_shows_metrics
    frame = render(left: 2, current_task: "TASK-42", current_task_seconds: 201.0)

    line = frame.lines[1]
    assert_includes line, "done 3"
    assert_includes line, "left 2"
    assert_includes line, "task TASK-42"
    assert_includes line, "00:03:21"
  end

  def test_waiting_state_line_with_no_open_tasks
    metrics = snapshot(current_task: nil, current_task_seconds: nil, left: 0)

    line = render(metrics: metrics, width: 80).lines[1]

    assert_includes line, "done 3"
    assert_includes line, "left 0"
    assert_includes line, "waiting: no open tasks (retry in 10s)"
  end

  def test_waiting_state_line_when_backlog_unavailable
    metrics = snapshot(current_task: nil, current_task_seconds: nil, left: nil)

    line = render(metrics: metrics, width: 80).lines[1]

    assert_includes line, "waiting: backlog unavailable (retry in 10s)"
    assert_includes line, "left ?"
  end

  def test_paused_overlay_replaces_the_task_state
    metrics = snapshot(current_task: "TASK-42", current_task_seconds: 10.0)

    line = render(metrics: metrics, paused: true).lines[1]

    assert_includes line, "PAUSED"
    refute_includes line, "task TASK-42"
  end

  def test_body_shows_lines_from_the_offset_window
    lines = (0..9).map { |i| "line #{i}" }
    frame = render(lines: lines, height: 8, offset: 2)

    body = frame.lines[3, 3]
    assert_equal ["line 2", "line 3", "line 4"], body.map(&:strip)
  end

  def test_missing_body_lines_are_blank
    frame = render(lines: ["one"], height: 8, offset: 0)

    body = frame.lines[3, 3]
    assert_equal "one", body[0].strip
    assert_equal "", body[1].strip
    assert_equal "", body[2].strip
  end

  def test_body_height_is_computed_from_terminal_height
    assert_equal 4, Letsdo::Tui::Renderer.body_height_for(8)
    assert_equal 1, Letsdo::Tui::Renderer.body_height_for(3)
  end

  def test_max_offset_and_clamp
    renderer = Letsdo::Tui::Renderer
    assert_equal 0, renderer.max_offset([], 3)
    assert_equal 7, renderer.max_offset((0..9).to_a, 3)
    assert_equal 0, renderer.clamp_offset(-5, (0..9).to_a, 3)
    assert_equal 0, renderer.clamp_offset(3, (0..2).to_a, 3)
  end

  def display_width(text)
    Unicode::DisplayWidth.of(text)
  end

  def test_long_lines_are_truncated_to_the_width
    long = "x" * 100
    frame = render(lines: [long], width: 30)

    body_line = frame.lines[3]
    assert_equal 30, display_width(body_line)
  end

  def test_lines_within_width_are_kept_verbatim
    frame = render(lines: ["ok"], width: 30)

    assert_equal "ok", frame.lines[3].strip
  end

  def test_frame_width_is_exact
    frame = render(width: 40)

    frame.lines.each do |line|
      assert_equal 40, display_width(line), "line must fit the width"
    end
  end

  def test_format_duration
    renderer = Letsdo::Tui::Renderer
    assert_equal "00:00:00", renderer.format_duration(0)
    assert_equal "00:12:34", renderer.format_duration(754)
    assert_equal "02:03:04", renderer.format_duration(7_384)
  end
end