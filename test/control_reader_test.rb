# frozen_string_literal: true

require_relative 'test_helper'

# Shared harness for the plain-mode control reader tests (TASK-94): the
# reader is driven over a real IO.pipe with the TTY gate forced on, so no
# real terminal is involved. The gate override is the only test seam — the
# reader's own tty? check is covered by the gating tests below.
module ControlReaderHelpers
  # A stub backend that records pause/resume calls.
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

  # An input that reports a TTY and fails on the first read.
  class FailingInput
    def tty?
      true
    end

    def gets
      raise IOError, 'input closed'
    end
  end

  def reader_for(read_io, **opts)
    Letsdo::Control::Reader.new(input: read_io, tty: true, **opts)
  end

  def close_and_join(write_io, reader)
    write_io&.close
    reader&.join(1)
  end

  def wait_until(timeout: 2)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      flunk 'reader did not react in time' if overdue?(deadline)
      sleep 0.005
    end
  end

  # Sends one 'p' line and waits for the expected gate state and calls.
  def toggle_pause(write_io, gate, runner, paused, calls)
    write_io.write("p\n")
    wait_until { gate.paused? == paused && runner.calls == calls }
  end

  # Starts the reader and sends the pause command until the gate flips.
  def press_p(reader, write_io, gate)
    reader.start
    write_io.write("p\n")
    wait_until { gate.paused? }
  end
end

# p/q command mapping of Letsdo::Control::Reader: 'p' toggles the shared
# PauseGate plus the running backend, 'q' requests the same clean stop as
# the TUI key and the stop signals.
class ControlReaderCommandTest < Minitest::Test
  include ControlReaderHelpers

  def test_p_toggles_the_gate_and_the_runner
    read_io, write_io = IO.pipe
    gate = Letsdo::Control::PauseGate.new
    runner = FakeRunner.new
    reader = reader_for(read_io, pause_gate: gate, runner: -> { runner })
    reader.start

    toggle_pause(write_io, gate, runner, true, [:pause])
    toggle_pause(write_io, gate, runner, false, %i[pause resume])
  ensure
    close_and_join(write_io, reader)
  end

  # 'p' between runs has no backend: the gate still toggles and nothing
  # is invoked on a nil runner (mirrors the TUI no-op).
  def test_p_without_gate_or_runner_is_a_no_op
    read_io, write_io = IO.pipe
    reader = reader_for(read_io)
    thread = reader.start
    write_io.write("p\n")
    write_io.close
    thread.join(1)

    assert_equal false, thread.status, 'reader crashed on a bare p'
  end

  def test_unknown_and_blank_lines_are_ignored
    read_io, write_io = IO.pipe
    gate = Letsdo::Control::PauseGate.new
    reader = reader_for(read_io, pause_gate: gate)
    thread = reader.start
    write_io.write("?\n\n  \n")
    write_io.close
    thread.join(1)

    assert_equal false, thread.status
    refute gate.paused?
  end

  # The default stop action is the TUI-equivalent one: Letsdo::Stopped is
  # raised into the main thread, which unwinds the same teardown path as
  # SIGINT/SIGTERM. The main thread sleeps so the raise is observed there.
  def test_quit_raises_stopped_into_the_main_thread
    read_io, write_io = IO.pipe
    reader = reader_for(read_io)
    reader.start

    assert_raises(Letsdo::Stopped) do
      write_io.write("q\n")
      sleep 2
    end
  ensure
    close_and_join(write_io, reader)
  end

  def test_quit_uses_the_injected_stop_action
    read_io, write_io = IO.pipe
    stopped = []
    reader = reader_for(read_io, on_stop: -> { stopped << true })
    reader.start

    write_io.write("q\n")
    wait_until { !stopped.empty? }

    assert_equal [true], stopped
  ensure
    close_and_join(write_io, reader)
  end

  # No escape codes, no echo, no partial lines: the reader is silent.
  def test_commands_write_nothing
    read_io, write_io = IO.pipe
    gate = Letsdo::Control::PauseGate.new
    reader = reader_for(read_io, pause_gate: gate)

    out, err = capture_io { press_p(reader, write_io, gate) }

    assert_empty out
    assert_empty err
  ensure
    close_and_join(write_io, reader)
  end
end

# TTY gating and quiet shutdown of Letsdo::Control::Reader.
class ControlReaderGatingTest < Minitest::Test
  include ControlReaderHelpers

  def test_start_returns_nil_for_a_non_tty_input
    read_io, write_io = IO.pipe
    reader = Letsdo::Control::Reader.new(input: read_io)

    assert_nil reader.start
    assert_nil reader.join(0)
  ensure
    read_io&.close
    write_io&.close
  end

  def test_non_tty_input_consumes_no_bytes
    read_io, write_io = IO.pipe
    write_io.write("p\nq\n")
    reader = Letsdo::Control::Reader.new(input: read_io)
    reader.start

    assert IO.select([read_io], nil, nil, 0), 'non-tty stdin was read from'
    assert_equal "p\nq\n", read_io.read_nonblock(16)
  ensure
    read_io&.close
    write_io&.close
  end

  def test_eof_exits_the_reader_quietly
    read_io, write_io = IO.pipe
    reader = reader_for(read_io)
    thread = reader.start
    write_io.close
    thread.join(1)

    assert_equal false, thread.status
  ensure
    read_io&.close
  end

  def test_read_error_exits_the_reader_quietly
    reader = reader_for(FailingInput.new)
    thread = reader.start
    thread.join(1)

    assert_equal false, thread.status
  end
end
