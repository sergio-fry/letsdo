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

# Shared fakes and assertions for Letsdo::SessionRecorder (TASK-69).
module SessionRecorderTestHelpers
  def fake_mono_clock(start = 0.0)
    FakeMonotonicClock.new(start)
  end

  def fake_wall_clock
    -> { '2026-09-04T08:00:00Z' }
  end

  def recorder(opts = {})
    Letsdo::SessionRecorder.new(
      name: 'developer', handle: '@developer',
      clock: opts.fetch(:clock, fake_mono_clock),
      wall_clock: opts.fetch(:wall_clock, fake_wall_clock),
      metrics_io: opts[:metrics_io]
    )
  end

  # Records one closed run, advancing the monotonic clock by +seconds+.
  def finish_run(rec, clock, task, code, seconds)
    rec.run_started(task)
    clock.advance(seconds)
    rec.run_finished(code)
  end

  def parse_jsonl(io)
    io.rewind
    io.readlines.filter_map { |line| JSON.parse(line) }
  end

  def jsonl_event(io, name)
    parse_jsonl(io).find { |event| event['event'] == name }
  end
end

# Per-run recording and outcome classification.
class SessionRecorderRunTest < Minitest::Test
  include SessionRecorderTestHelpers

  def test_run_started_records_task_id_and_start_time
    mono = fake_mono_clock(100.0)
    rec = recorder(clock: mono)
    rec.run_started('TASK-42')
    run = rec.summary.runs.first

    assert_equal 'TASK-42', run.task_id
    assert_in_delta 100.0, run.started_mono, 0.001
    assert_nil run.finished_mono
  end

  def test_run_finished_records_elapsed_exit_code_and_done_outcome
    mono = fake_mono_clock(100.0)
    rec = recorder(clock: mono)
    finish_run(rec, mono, 'TASK-42', 0, 2.0)
    run = rec.summary.runs.first

    assert_equal 0, run.exit_code
    assert_equal :done, run.outcome
    assert_in_delta 2.0, run.elapsed_s, 0.001
  end

  def test_nonzero_exit_code_is_a_failed_outcome
    mono = fake_mono_clock(100.0)
    rec = recorder(clock: mono)
    finish_run(rec, mono, 'TASK-42', 1, 1.0)

    assert_equal :failed, rec.summary.runs.first.outcome
  end

  def test_nil_exit_code_counts_as_failed
    mono = fake_mono_clock(100.0)
    rec = recorder(clock: mono)
    finish_run(rec, mono, 'TASK-42', nil, 1.0)

    assert_equal :failed, rec.summary.runs.first.outcome
  end

  def test_run_finished_is_noop_when_no_run_is_open
    rec = recorder
    rec.run_finished(0)

    assert_empty rec.summary.runs
  end
end

# Latest left count and summary aggregation / summary_line.
class SessionRecorderSummaryTest < Minitest::Test
  include SessionRecorderTestHelpers

  def test_provider_result_tracks_latest_left_count
    rec = recorder
    rec.provider_result(3)

    assert_equal 3, rec.summary.left
  end

  def test_provider_result_nil_means_unreadable
    rec = recorder
    rec.provider_result(3)
    rec.provider_result(nil)

    assert_nil rec.summary.left
  end

  def test_summary_counts_done_failed_and_interrupted
    mono = fake_mono_clock(0.0)
    rec = recorder(clock: mono)
    rec.provider_result(2)
    finish_run(rec, mono, 'TASK-1', 0, 2.0)
    finish_run(rec, mono, 'TASK-2', 1, 2.0)
    rec.run_started('TASK-3')
    s = rec.summary

    assert_equal [1, 1, 1, 2], [s.done, s.failed, s.interrupted, s.left]
  end

  def test_summary_derives_session_active_waiting_and_avg
    mono = fake_mono_clock(0.0)
    rec = recorder(clock: mono)
    finish_run(rec, mono, 'TASK-1', 0, 4.0)
    s = rec.summary

    assert_in_delta 4.0, s.session_s, 0.001
    assert_in_delta 4.0, s.active_s, 0.001
    assert_in_delta 0.0, s.waiting_s, 0.001
    assert_in_delta 4.0, s.avg_s, 0.001
  end

  def test_avg_is_zero_when_no_done_runs
    assert_equal 0.0, recorder.summary.avg_s
  end

  def test_summary_line_reports_totals_and_the_run
    mono = fake_mono_clock(0.0)
    rec = recorder(clock: mono)
    rec.provider_result(0)
    finish_run(rec, mono, 'TASK-42', 0, 3.0)
    line = rec.summary_line

    assert_includes line, 'letsdo: session: 1 done, 0 failed, 0 interrupted, 0 left open'
    assert_includes line, '(3s in runs, 0s waiting, avg 3s)'
    assert_includes line, 'letsdo:   TASK-42 done in 3s'
  end

  def test_summary_line_shows_unknown_when_left_is_nil
    assert_includes recorder.summary_line, 'unknown left open'
  end

  def test_summary_line_caps_at_ten_run_lines
    mono = fake_mono_clock(0.0)
    rec = recorder(clock: mono)
    12.times { |i| finish_run(rec, mono, "TASK-#{i}", 0, 1.0) }
    lines = rec.summary_line.split("\n")

    assert_equal 12, lines.length
    assert_includes lines.last, '… and 2 more'
  end
end

# Optional JSONL event stream.
class SessionRecorderJsonlTest < Minitest::Test
  include SessionRecorderTestHelpers

  def test_jsonl_session_start_event
    io = StringIO.new
    recorder(metrics_io: io)
    event = jsonl_event(io, 'session_start')

    assert_equal 'developer', event['agent']
    assert_equal '@developer', event['handle']
  end

  def test_jsonl_run_finished_event
    io = StringIO.new
    mono = fake_mono_clock(0.0)
    rec = recorder(metrics_io: io, clock: mono)
    finish_run(rec, mono, 'TASK-42', 0, 2.0)
    event = jsonl_event(io, 'run_finished')

    assert_equal 'TASK-42', event['task']
    assert_equal 0, event['exit']
    assert_equal 'done', event['outcome']
    assert_in_delta 2.0, event['elapsed_s'], 0.001
    assert_equal '2026-09-04T08:00:00Z', event['ts']
  end

  def test_jsonl_session_stop_event
    io = StringIO.new
    mono = fake_mono_clock(0.0)
    rec = recorder(metrics_io: io, clock: mono)
    rec.provider_result(0)
    finish_run(rec, mono, 'TASK-42', 0, 2.0)
    rec.session_stop
    event = jsonl_event(io, 'session_stop')

    assert_equal [1, 0, 0, 0], [event['done'], event['failed'], event['interrupted'], event['left']]
    assert_in_delta 2.0, event['session_s'], 0.001
  end

  def test_session_stop_writes_event_only_once
    io = StringIO.new
    rec = recorder(metrics_io: io)
    first = rec.session_stop
    second = rec.session_stop

    assert_equal 2, parse_jsonl(io).length
    assert_equal first, second
  end

  def test_recorder_without_metrics_io_still_records
    rec = recorder(metrics_io: nil)
    finish_run(rec, fake_mono_clock, 'TASK-1', 0, 1.0)

    assert_equal 1, rec.summary.done
  end
end

# Builder wiring for LETSDO_METRICS_FILE.
class SessionRecorderMetricsIoTest < Minitest::Test
  include SessionRecorderTestHelpers

  def test_metrics_io_warns_and_returns_nil_for_invalid_path
    err = StringIO.new
    builder = builder_for_metrics('/nonexistent/dir/metrics.jsonl', stderr: err)

    assert_nil builder.metrics_io
    assert_includes err.string, 'letsdo: cannot open metrics file'
  end

  def test_metrics_io_returns_io_for_valid_path
    Dir.mktmpdir do |dir|
      io = builder_for_metrics(File.join(dir, 'metrics.jsonl')).metrics_io

      refute_nil io
      io.close
    end
  end

  private

  def builder_for_metrics(path, stderr: StringIO.new)
    Letsdo::CLI::Builder.new(
      env: { 'LETSDO_METRICS_FILE' => path },
      stdout: StringIO.new, stderr: stderr, stdin: StringIO.new,
      sleeper: ->(_seconds) { throw Letsdo::AgentLoop::STOP }
    )
  end
end
