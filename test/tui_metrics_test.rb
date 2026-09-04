# frozen_string_literal: true

require_relative "test_helper"

class TuiMetricsTest < Minitest::Test
  # A controllable monotonic clock: advances by hand, makes snapshots exact.
  def fake_clock(t = 0.0)
    current = t
    -> { current }
  end

  def test_initial_snapshot_has_identity_and_zero_metrics
    metrics = Letsdo::Tui::Metrics.new(name: "developer", handle: "@developer",
                                       clock: fake_clock(100.0))

    snapshot = metrics.snapshot

    assert_equal "developer", snapshot.name
    assert_equal "@developer", snapshot.handle
    assert_equal 0, snapshot.done
    assert_nil snapshot.left
    assert_nil snapshot.current_task
    assert_nil snapshot.current_task_seconds
    assert_equal 0.0, snapshot.session_seconds
  end

  def test_run_events_track_done_and_current_task
    clock = -> { @t }
    @t = 0.0
    metrics = Letsdo::Tui::Metrics.new(name: "developer", handle: "@developer", clock: clock)

    @t = 5.0
    metrics.run_started("TASK-42")
    snapshot = metrics.snapshot
    assert_equal "TASK-42", snapshot.current_task
    assert_equal 0.0, snapshot.current_task_seconds
    assert_equal 0, snapshot.done

    @t = 6.5
    snapshot = metrics.snapshot
    assert_equal 1.5, snapshot.current_task_seconds

    @t = 10.0
    metrics.run_finished
    snapshot = metrics.snapshot
    assert_nil snapshot.current_task
    assert_equal 1, snapshot.done
  end

  def test_provider_result_records_left_count
    metrics = Letsdo::Tui::Metrics.new(name: "a", handle: "@a", clock: fake_clock)
    metrics.provider_result(3)

    assert_equal 3, metrics.snapshot.left
  end

  def test_provider_result_nil_means_unreadable
    metrics = Letsdo::Tui::Metrics.new(name: "a", handle: "@a", clock: fake_clock)
    metrics.provider_result(2)
    metrics.provider_result(nil)

    assert_nil metrics.snapshot.left
  end

  def test_on_run_start_hook_is_called_with_the_task
    seen = []
    metrics = Letsdo::Tui::Metrics.new(name: "a", handle: "@a", clock: fake_clock,
                                       on_run_start: ->(task) { seen << task })

    metrics.run_started("TASK-1")

    assert_equal ["TASK-1"], seen
  end

  def test_session_seconds_grow_with_the_clock
    current = 0.0
    metrics = Letsdo::Tui::Metrics.new(name: "a", handle: "@a", clock: -> { current })

    current = 42.0
    assert_equal 42.0, metrics.snapshot.session_seconds
  end
end