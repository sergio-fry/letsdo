# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# Session tests drive the full controller with injected components only:
# a pipe keyboard (real Tui::Input decoding escape bytes), a StringIO
# terminal with a fixed size provider, a real LogBuffer and Metrics with a
# controllable clock, and a scripted orchestrator block. No real TTY.
#
# The base class holds the shared harness; each concern below is its own
# test class so every class stays within the default length limits.
class TuiSessionTest < Minitest::Test
  HOME = "\e[1;1H"
  ENTER_ALT = "\e[?1049h"
  LEAVE_ALT = "\e[?1049l"

  def setup
    @terminal_io = StringIO.new
    @clock = 0.0
    @log = Letsdo::Tui::LogBuffer.new
    @metrics = Letsdo::Tui::Metrics.new(name: 'developer', handle: '@developer',
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
      name: 'developer', handle: '@developer', log: @log, metrics: @metrics,
      terminal: terminal, input: input_for(keys), refresh: refresh,
      wait_seconds: 10, clock: -> { @clock }
    )
    session.run(&work)
  end

  # A stub standing in for Letsdo::PiRunner: records pause/resume.
  class FakeRunner
    attr_reader :calls

    def initialize
      @calls = []
    end

    def pause
      @calls << :pause
    end

    def resume
      @calls << :resume
    end
  end

  # Runs a session with the real pause wiring (gate + runner) injected.
  def run_session_controlled(keys, gate:, runner:, &work)
    session = Letsdo::Tui::Session.new(
      name: 'developer', handle: '@developer', log: @log, metrics: @metrics,
      terminal: terminal, input: input_for(keys),
      wait_seconds: 10, clock: -> { @clock },
      pause_gate: gate, runner: -> { runner }
    )
    session.run(&work)
  end

  # The rendered frames (terminal writes between the HOME prefixes).
  # Leave-screen bytes are appended after the last frame, so they are
  # stripped first; otherwise split(HOME) would drop that last frame.
  def frames
    body = @terminal_io.string.sub(/#{Regexp.escape(LEAVE_ALT)}\z/, '')
    parts = body.split(HOME)
    parts.shift # enter sequence, no HOME before the first frame
    parts
  end

  def seed_lines(count)
    @log.write("#{(0...count).map { |i| "line #{i}" }.join("\n")}\n")
  end
end

# Basic lifecycle: quit, first frame, work result, work errors.
class TuiSessionRenderTest < TuiSessionTest
  def test_quit_restores_the_terminal_and_returns_zero
    result = run_session('q') do
      sleep 0.5
      :not_reached
    end

    assert_equal 0, result
    assert_includes @terminal_io.string, ENTER_ALT
    assert_includes @terminal_io.string, LEAVE_ALT
  end

  def test_initial_frame_shows_header_and_log
    seed_lines(3)
    @metrics.provider_result(76)
    @metrics.run_started('TASK-42')
    @clock = 30.0
    run_session('q') do
      sleep 0.5
      0
    end

    assert_initial_frame(frames.first)
  end

  def assert_initial_frame(first)
    assert_includes first, 'letsdo · developer (@developer)'
    assert_includes first, 'session 00:00:30'
    assert_includes first, 'done 0'
    assert_includes first, 'left 76'
    assert_includes first, 'task TASK-42'
    assert_includes first, 'line 0'
    assert_includes first, '↑/↓ PgUp/PgDn scroll · p pause · r refresh · q quit'
  end

  def test_pause_shows_paused_overlay
    run_session('pq') do
      sleep 0.5
      0
    end

    refute_includes frames.first, 'PAUSED'
    assert_includes frames.last, 'PAUSED'
  end

  def test_work_result_is_returned_when_not_stopped
    result = run_session('') { 7 }

    assert_equal 7, result
    assert_includes @terminal_io.string, LEAVE_ALT
  end

  def test_terminal_is_restored_even_when_the_work_raises
    session = Letsdo::Tui::Session.new(
      name: 'developer', handle: '@developer', log: @log, metrics: @metrics,
      terminal: terminal, input: input_for(''), wait_seconds: 10, clock: -> { @clock }
    )

    assert_raises(RuntimeError) do
      session.run { raise 'boom' }
    end
    assert_includes @terminal_io.string, LEAVE_ALT
  end
end

# Real pause semantics (TASK-74): the runner is suspended mid-run, the
# gate holds new runs while paused, quit while paused exits cleanly.
class TuiSessionPauseTest < TuiSessionTest
  def test_pause_mid_run_suspends_the_runner_and_the_gate
    gate = Letsdo::Control::PauseGate.new
    runner = FakeRunner.new
    @metrics.run_started('TASK-74') # a run is active — runner exists

    run_session_controlled('pq', gate: gate, runner: runner) do
      sleep 0.5
      0
    end

    assert_equal [:pause], runner.calls, "mid-run 'p' must SIGSTOP the runner"
    assert gate.paused?, "mid-run 'p' must hold the gate too"
    assert_includes frames.last, 'PAUSED'
  end

  def test_second_pause_resumes_runner_and_gate
    gate = Letsdo::Control::PauseGate.new
    runner = FakeRunner.new
    @metrics.run_started('TASK-74')

    run_session_controlled('ppq', gate: gate, runner: runner) do
      sleep 0.5
      0
    end

    assert_equal %i[pause resume], runner.calls
    refute gate.paused?
  end

  def run_gate_session(keys, gate)
    run_session_controlled(keys, gate: gate, runner: nil) do
      sleep 0.5
      0
    end
  end

  def test_pause_between_runs_toggles_only_the_gate
    gate = Letsdo::Control::PauseGate.new
    # No run started — the runner accessor returns nil (absent runner).
    run_gate_session('pq', gate)

    assert gate.paused?, "waiting-state 'p' must hold the gate"
    assert_includes frames.last, 'PAUSED'

    run_gate_session('ppq', gate)
    refute gate.paused?, "second 'p' must release the gate"
  end

  def test_pause_without_gate_or_runner_stays_display_only
    # No gate, no runner (unit contexts): 'p' is the TASK-42 display
    # freeze only — and must not crash.
    run_session('pq') do
      sleep 0.5
      0
    end

    assert_includes frames.last, 'PAUSED'
  end

  def test_footer_shows_pause_vs_resume_by_state
    run_session('p q'.delete(' ')) do
      sleep 0.3
      0
    end

    refute_includes frames.first, 'p resume'
    assert_includes frames.first, 'p pause'
    assert_includes frames.last, 'p resume'
    refute_includes frames.last, 'p pause'
  end

  def run_paused_runner_session(keys, gate, runner)
    run_session_controlled(keys, gate: gate, runner: runner) do
      sleep 0.5
      :not_reached
    end
  end

  def test_quit_while_paused_restores_the_terminal_and_exits_zero
    gate = Letsdo::Control::PauseGate.new
    runner = FakeRunner.new
    @metrics.run_started('TASK-74')

    result = run_paused_runner_session('pq', gate, runner)

    assert_equal 0, result
    assert_equal [:pause], runner.calls
    assert_includes @terminal_io.string, ENTER_ALT
    assert_includes @terminal_io.string, LEAVE_ALT
  end
end

# Scrolling and follow-mode behaviour over a multi-line log.
class TuiSessionScrollTest < TuiSessionTest
  def test_scroll_up_leaves_follow_mode
    seed_lines(30)
    run_session("\e[Aq") do
      sleep 0.5
      0
    end

    last = frames.last
    assert_includes last, 'line 26'
    assert_includes last, 'line 28'
    refute_includes last, 'line 29'
  end

  def test_end_resticks_to_the_bottom
    seed_lines(30)
    run_session("\e[A\e[Fq") do
      sleep 0.5
      0
    end

    last = frames.last
    assert_includes last, 'line 29'
  end

  def test_home_scrolls_to_the_top
    seed_lines(30)
    run_session("\e[Hq") do
      sleep 0.5
      0
    end

    last = frames.last
    assert_includes last, 'line 0'
    refute_includes last, 'line 29'
  end

  def test_new_log_lines_re_stick_the_follow_view
    seed_lines(3)
    run_session('') do
      sleep 0.05
      @log.write("line 3\n")
      sleep 0.3
    end

    last = frames.last
    assert_includes last, 'line 3'
  end
end

# The refresh hook: 'r' recollects the provider count into the metrics.
class TuiSessionRefreshTest < TuiSessionTest
  def test_refresh_collects_the_provider_count
    @metrics.provider_result(2)
    refresh = -> { 5 }
    run_session('rq', refresh: refresh) do
      sleep 0.5
      0
    end

    assert_includes frames.last, 'left 5'
    assert_equal 5, @metrics.snapshot.left
  end
end

# A keyboard that reports tty? and counts raw-mode entry/exit, so a test can
# assert the terminal state is restored after the session ends (TASK-83).
class RawTrackingStdin
  attr_reader :raw_enters, :raw_exits

  def initialize
    @raw_enters = 0
    @raw_exits = 0
  end

  def tty?
    true
  end

  def raw
    @raw_enters += 1
    yield
  ensure
    @raw_exits += 1
  end
end

# An input that scripts keys and exposes the raw-tracking stdin.
class ScriptedRawInput
  KEY_BY_CHAR = { 'q' => :q, 'p' => :p }.freeze

  attr_reader :stdin

  def initialize(keys)
    @stdin = RawTrackingStdin.new
    @keys = keys.dup
  end

  def next_key
    KEY_BY_CHAR[@keys.shift]
  end
end

# Raw-mode lifecycle: the terminal is left in raw mode while the session
# runs and restored on every quit path — key quit and a raised stop.
class TuiSessionRawModeTest < TuiSessionTest
  def run_raw_session(keys, &work)
    @input = ScriptedRawInput.new(keys)
    session = Letsdo::Tui::Session.new(
      name: 'developer', handle: '@developer', log: @log, metrics: @metrics,
      terminal: terminal, input: @input,
      wait_seconds: 10, clock: -> { @clock }
    )
    session.run(&work)
  end

  def test_key_quit_restores_raw_mode
    result = run_raw_session(['q']) { sleep 0.5 }

    assert_equal 0, result
    assert_equal 1, @input.stdin.raw_enters
    assert_equal 1, @input.stdin.raw_exits
  end

  def test_signal_stop_restores_raw_mode
    result = run_raw_session([]) { raise Letsdo::Stopped }

    assert_equal 0, result
    assert_equal 1, @input.stdin.raw_enters
    assert_equal 1, @input.stdin.raw_exits
  end
end
