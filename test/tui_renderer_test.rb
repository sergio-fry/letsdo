# frozen_string_literal: true

require_relative 'test_helper'
require 'unicode/display_width'

# The renderer is a pure function: (metrics snapshot, log lines, size,
# view, wait interval) → framed String. Every test here builds inputs
# directly — no terminal, no IO, no TTY.
#
# The base class holds the shared harness; each concern below is its own
# test class so every class stays within the default length limits.
class TuiRendererTest < Minitest::Test
  SNAPSHOT = Letsdo::Tui::Metrics::Snapshot
  FRAME_KEYS = %i[metrics lines width height offset paused wait_seconds].freeze

  def snapshot(done: 3, left: 2, session_seconds: 754.0, current_task: 'TASK-42',
               current_task_seconds: 201.0)
    SNAPSHOT.new(name: 'developer', handle: '@developer', done: done, left: left,
                 session_seconds: session_seconds, current_task: current_task,
                 current_task_seconds: current_task_seconds)
  end

  def render(**opts)
    Letsdo::Tui::Renderer.render(**renderer_args(opts))
  end

  def renderer_args(opts)
    {
      metrics: opts.fetch(:metrics) { snapshot(**snapshot_from(opts)) },
      lines: opts.fetch(:lines, []),
      size: { width: opts.fetch(:width, 60), height: opts.fetch(:height, 10) },
      view: { offset: opts.fetch(:offset, 0), paused: opts.fetch(:paused, false) },
      wait_seconds: opts.fetch(:wait_seconds, 10.0)
    }
  end

  def snapshot_from(opts)
    snap = opts.dup
    FRAME_KEYS.each { |key| snap.delete(key) }
    snap
  end

  def display_width(text)
    Unicode::DisplayWidth.of(text)
  end
end

# Header, footer, and the running / waiting / paused state line.
class TuiRendererChromeTest < TuiRendererTest
  def test_header_shows_name_handle_and_session_timer
    line = render(session_seconds: 754.0).lines[0]

    assert_includes line, 'letsdo · developer (@developer)'
    assert_includes line, 'session 00:12:34'
  end

  def test_footer_lists_keys
    assert_includes render.lines[-1], '↑/↓ PgUp/PgDn scroll · p pause · r refresh · q quit'
  end

  def test_footer_hint_flips_to_resume_when_paused
    line = render(paused: true).lines[-1]

    assert_includes line, 'p resume'
    refute_includes line, 'p pause'
  end

  def test_running_state_line_shows_metrics
    line = render(left: 2, current_task: 'TASK-42', current_task_seconds: 201.0).lines[1]

    assert_includes line, 'done 3'
    assert_includes line, 'left 2'
    assert_includes line, 'task TASK-42'
    assert_includes line, '00:03:21'
  end

  def test_waiting_state_line_with_no_open_tasks
    metrics = snapshot(current_task: nil, current_task_seconds: nil, left: 0)
    line = render(metrics: metrics, width: 80).lines[1]

    assert_includes line, 'done 3'
    assert_includes line, 'left 0'
    assert_includes line, 'waiting: no open tasks (retry in 10s)'
  end

  def test_waiting_state_line_when_backlog_unavailable
    metrics = snapshot(current_task: nil, current_task_seconds: nil, left: nil)
    line = render(metrics: metrics, width: 80).lines[1]

    assert_includes line, 'waiting: backlog unavailable (retry in 10s)'
    assert_includes line, 'left ?'
  end

  def test_paused_overlay_replaces_the_task_state
    metrics = snapshot(current_task: 'TASK-42', current_task_seconds: 10.0)
    line = render(metrics: metrics, paused: true).lines[1]

    assert_includes line, 'PAUSED'
    refute_includes line, 'task TASK-42'
  end
end

# Scrollable body window, truncation, and exact frame width.
class TuiRendererBodyTest < TuiRendererTest
  def test_body_shows_lines_from_the_offset_window
    lines = (0..9).map { |i| "line #{i}" }
    body = render(lines: lines, height: 8, offset: 2).lines[3, 3]

    assert_equal ['line 2', 'line 3', 'line 4'], body.map(&:strip)
  end

  def test_missing_body_lines_are_blank
    body = render(lines: ['one'], height: 8, offset: 0).lines[3, 3]

    assert_equal 'one', body[0].strip
    assert_equal '', body[1].strip
    assert_equal '', body[2].strip
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

  def test_long_lines_are_truncated_to_the_width
    body_line = render(lines: ['x' * 100], width: 30).lines[3]

    assert_equal 30, display_width(body_line)
  end

  def test_lines_within_width_are_kept_verbatim
    assert_equal 'ok', render(lines: ['ok'], width: 30).lines[3].strip
  end

  def test_frame_width_is_exact
    render(width: 40).lines.each do |line|
      assert_equal 40, display_width(line), 'line must fit the width'
    end
  end
end

# Duration formatting lives on Renderer::Text after the style split that
# kept Renderer itself within the default method/class length limits.
class TuiRendererTextTest < TuiRendererTest
  def test_format_duration
    text = Letsdo::Tui::Renderer::Text

    assert_equal '00:00:00', text.format_duration(0)
    assert_equal '00:12:34', text.format_duration(754)
    assert_equal '02:03:04', text.format_duration(7_384)
  end
end
