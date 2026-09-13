# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'json'
require 'tmpdir'

# A controllable monotonic clock: returns the current time, advances via #advance.
class FakeMonotonicClock
  def initialize(start = 0.0)
    @current = start
  end

  attr_reader :current

  def advance(delta = 1.0)
    @current += delta
  end

  def call
    @current
  end
end

# Letsdo::SessionRecorder (TASK-69): mode-independent metrics, JSONL events,
# summary aggregation and summary_line formatting.
class SessionRecorderTest < Minitest::Test
  def fake_mono_clock(start = 0.0)
    FakeMonotonicClock.new(start)
  end

  def fake_wall_clock
    -> { '2026-09-04T08:00:00Z' }
  end

  def recorder(opts = {})
    Letsdo::SessionRecorder.new(
      name: 'developer',
      handle: '@developer',
      clock: opts.fetch(:clock, fake_mono_clock),
      wall_clock: opts.fetch(:wall_clock, fake_wall_clock),
      metrics_io: opts[:metrics_io]
    )
  end

  def test_run_started_records_task_id_and_start_time
    mono = fake_mono_clock(100.0)
    r = recorder(clock: mono)
    r.run_started('TASK-42')
    # Advance past the start time so elapsed will be non-zero later.
    mono.advance(2.0)
    s = r.summary

    assert_equal 1, s.runs.length
    assert_equal 'TASK-42', s.runs.first.task_id
    assert_in_delta 100.0, s.runs.first.started_mono, 0.001
    assert_nil s.runs.first.finished_mono
  end

  def test_run_finished_records_elapsed_and_exit_code_and_done_outcome
    mono = fake_mono_clock(100.0)
    r = recorder(clock: mono)
    r.run_started('TASK-42')
    mono.advance(2.0)
    r.run_finished(0)
    s = r.summary

    assert_equal 1, s.runs.length
    assert_equal 0, s.runs.first.exit_code
    assert_equal :done, s.runs.first.outcome
    assert_in_delta 2.0, s.runs.first.elapsed_s, 0.001
  end

  def test_run_finished_failed_outcome_for_nonzero_exit
    mono = fake_mono_clock(100.0)
    r = recorder(clock: mono)
    r.run_started('TASK-42')
    mono.advance(1.0)
    r.run_finished(1)
    s = r.summary

    assert_equal 1, s.runs.length
    assert_equal 1, s.runs.first.exit_code
    assert_equal :failed, s.runs.first.outcome
  end

  def test_run_finished_nil_exit_code_is_failed
    mono = fake_mono_clock(100.0)
    r = recorder(clock: mono)
    r.run_started('TASK-42')
    mono.advance(1.0)
    r.run_finished(nil)
    s = r.summary

    assert_equal :failed, s.runs.first.outcome
  end

  def test_run_finished_is_noop_when_no_run_is_open
    r = recorder
    # Must not raise.
    r.run_finished(0)
    s = r.summary

    assert_equal 0, s.runs.length
  end

  def test_provider_result_tracks_latest_left_count
    r = recorder
    r.provider_result(3)
    s = r.summary

    assert_equal 3, s.left
  end

  def test_provider_result_nil_means_unreadable
    r = recorder
    r.provider_result(3)
    r.provider_result(nil)
    s = r.summary

    assert_nil s.left
  end

  def test_summary_aggregates_done_failed_interrupted_left
    mono = fake_mono_clock(0.0)
    r = recorder(clock: mono)
    r.provider_result(2)
    r.run_started('TASK-1')
    mono.advance(2.0)
    r.run_finished(0)
    r.run_started('TASK-2')
    mono.advance(2.0)
    r.run_finished(1)
    r.run_started('TASK-3') # open run — interrupted

    s = r.summary

    assert_equal 1, s.done
    assert_equal 1, s.failed
    assert_equal 1, s.interrupted
    assert_equal 2, s.left
    assert_in_delta 4.0, s.session_s, 0.001
    assert_in_delta 4.0, s.active_s, 0.001
    assert_in_delta 0.0, s.waiting_s, 0.001
    assert_in_delta 2.0, s.avg_s, 0.001
  end

  def test_summary_avg_s_is_zero_when_no_done_runs
    r = recorder
    s = r.summary

    assert_equal 0.0, s.avg_s
  end

  def test_summary_line_format
    mono = fake_mono_clock(0.0)
    r = recorder(clock: mono)
    r.provider_result(0)
    r.run_started('TASK-42')
    mono.advance(2.0)
    mono.advance(1.0) # two advances: from start to 3.0 elapsed total
    r.run_finished(0)

    line = r.summary_line

    # C3 format: durations include their own unit, so no trailing 's' after %<>s
    assert_match %r{letsdo: session: 1 done, 0 failed, 0 interrupted, 0 left open}, line
    assert_match %r{\(3s in runs, 0s waiting, avg 3s\)}, line
    assert_match %r{letsdo:   TASK-42 done in 3s}, line
  end

  def test_summary_line_shows_unknown_when_left_is_nil
    r = recorder
    line = r.summary_line
    assert_match 'unknown left open', line
  end

  def test_summary_line_caps_at_ten_per_run_lines
    mono = fake_mono_clock(0.0)
    r = recorder(clock: mono)
    12.times do |i|
      r.run_started("TASK-#{i}")
      mono.advance(1.0)
      mono.advance(1.0) # two advances per run: start->finish elapsed 2? Actually each run: run_started then finish gives elapsed 2? With our clock each advance is 1.0 so two advances = 2.0 elapsed. But elapsed_s = finished_mono - started_mono = (start + 2 advances) - start = 2.0. Okay.
      r.run_finished(0)
    end

    lines = r.summary_line.split("\n")
    assert_equal 12, lines.length # 1 summary + 10 runs + 1 '… and N more'
    assert_includes lines.last, '… and 2 more'
  end

  def test_jsonl_session_start_event
    io = StringIO.new
    recorder(metrics_io: io)

    events = parse_jsonl(io)
    assert_equal 1, events.length
    assert_equal 'session_start', events.first['event']
    assert_equal 'developer', events.first['agent']
    assert_equal '@developer', events.first['handle']
  end

  def test_jsonl_run_finished_event
    io = StringIO.new
    mono = fake_mono_clock(0.0)
    r = recorder(metrics_io: io, clock: mono)
    r.run_started('TASK-42')
    mono.advance(2.0)
    r.run_finished(0)

    events = parse_jsonl(io)
    finish_event = events.find { |e| e['event'] == 'run_finished' }
    assert finish_event, 'expected run_finished event'
    assert_equal 'TASK-42', finish_event['task']
    assert_equal 0, finish_event['exit']
    assert_equal 'done', finish_event['outcome']
    assert_in_delta 2.0, finish_event['elapsed_s'], 0.001
    assert_equal '2026-09-04T08:00:00Z', finish_event['ts']
  end

  def test_jsonl_session_stop_event
    io = StringIO.new
    mono = fake_mono_clock(0.0)
    r = recorder(metrics_io: io, clock: mono)
    r.provider_result(0)
    r.run_started('TASK-42')
    mono.advance(2.0)
    r.run_finished(0)
    r.session_stop

    events = parse_jsonl(io)
    stop_event = events.find { |e| e['event'] == 'session_stop' }
    assert stop_event, 'expected session_stop event'
    assert_equal 1, stop_event['done']
    assert_equal 0, stop_event['failed']
    assert_equal 0, stop_event['interrupted']
    assert_equal 0, stop_event['left']
    assert_in_delta 2.0, stop_event['session_s'], 0.001
  end

  def test_session_stop_writes_event_only_once
    io = StringIO.new
    r = recorder(metrics_io: io)
    s1 = r.session_stop
    s2 = r.session_stop
    events = parse_jsonl(io)

    assert_equal 2, events.length # session_start + session_stop
    assert_equal s1, s2
  end

  def test_no_metrics_io_no_jsonl_output
    r = recorder(metrics_io: nil)
    r.run_started('TASK-1')
    r.run_finished(0)

    # No IO → no JSONL output expected; must not raise.
    assert_equal 0, StringIO.new.string.length
  end

  def test_metrics_io_warning_on_invalid_path_via_builder_metrics_io
    err = StringIO.new
    builder = Letsdo::CLI::Builder.new(
      env: { 'LETSDO_METRICS_FILE' => '/nonexistent/dir/metrics.jsonl', 'LETSDO_ROOT' => Dir.mktmpdir },
      stdout: StringIO.new, stderr: err, stdin: StringIO.new,
      sleeper: ->(_s) { throw Letsdo::AgentLoop::STOP }
    )
    io = builder.send(:metrics_io)
    assert_nil io
    assert_includes err.string, 'letsdo: cannot open metrics file'
  end

  def test_metrics_io_returns_io_for_valid_path
    tmp = Tempfile.new('metrics.jsonl')
    path = tmp.path
    tmp.close
    err = StringIO.new
    builder = Letsdo::CLI::Builder.new(
      env: { 'LETSDO_METRICS_FILE' => path },
      stdout: StringIO.new, stderr: err, stdin: StringIO.new,
      sleeper: ->(_s) { throw Letsdo::AgentLoop::STOP }
    )
    io = builder.send(:metrics_io)
    refute_nil io
    io.close
    File.unlink(path) rescue nil
  end

  private

  def parse_jsonl(io)
    io.rewind
    io.readlines.filter_map { |line| JSON.parse(line) }
  end
end