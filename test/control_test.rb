# frozen_string_literal: true

require_relative 'test_helper'

# Letsdo::Control::PauseGate: a mutex-guarded pause flag shared between
# the TUI input thread (toggling on 'p') and the loop's main thread
# (polling before each run).
class ControlTest < Minitest::Test
  def test_defaults_to_not_paused
    gate = Letsdo::Control::PauseGate.new

    refute gate.paused?
  end

  def test_pause_and_resume_toggle_the_flag
    gate = Letsdo::Control::PauseGate.new
    gate.pause
    assert gate.paused?

    gate.resume
    refute gate.paused?
  end

  def test_repeated_pause_and_resume_are_idempotent
    gate = Letsdo::Control::PauseGate.new
    gate.pause
    gate.pause
    assert gate.paused?

    gate.resume
    gate.resume
    refute gate.paused?
  end

  # The whole point of the mutex: the flag is toggled from one thread
  # ('p' key) while another polls it (the loop). Two threads hammering
  # pause/resume must produce a consistent flag and no deadlock.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_thread_safe_toggle_from_two_threads
    gate = Letsdo::Control::PauseGate.new
    errors = Queue.new
    iterations = 500

    # One thread toggles pause/resume, another polls (and re-pauses) —
    # any intermediate value is legal, the invariant is that the access
    # never crashes or corrupts the flag.
    toggler = Thread.new do
      iterations.times do
        gate.pause
        gate.resume
      end
    rescue StandardError => e
      errors << e
    end
    observer = Thread.new do
      observer_loop(gate, iterations)
    rescue StandardError => e
      errors << e
    end

    toggler.join(5)
    observer.join(5)
    refute toggler.alive?, 'toggler deadlocked'
    refute observer.alive?, 'observer deadlocked'
    begin
      popped = errors.pop(true)
    rescue ThreadError
      popped = nil
    end
    assert_nil popped, "thread raised: #{popped.inspect}"
    refute gate.paused?
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  def observer_loop(gate, iterations)
    iterations.times do
      state = gate.paused?
      gate.pause if state
    end
  end
end
