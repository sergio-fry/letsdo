# frozen_string_literal: true

require_relative 'test_helper'

# Letsdo::Metrics::Fanout (TASK-69): forwards loop-driver events to every
# observer so the session recorder and the TUI header share the same callbacks.
class FanoutTest < Minitest::Test
  def test_provider_result_forwards_to_every_observer
    o1 = observed
    o2 = observed
    fanout = Letsdo::Metrics::Fanout.new(o1, o2)
    fanout.provider_result(3)

    assert_equal [[:provider, 3]], o1.events
    assert_equal [[:provider, 3]], o2.events
  end

  def test_provider_result_nil_forwards_to_every_observer
    o1 = observed
    o2 = observed
    fanout = Letsdo::Metrics::Fanout.new(o1, o2)
    fanout.provider_result(nil)

    assert_equal [[:provider, nil]], o1.events
    assert_equal [[:provider, nil]], o2.events
  end

  def test_run_started_forwards_to_every_observer
    o1 = observed
    o2 = observed
    fanout = Letsdo::Metrics::Fanout.new(o1, o2)
    fanout.run_started('TASK-42')

    assert_equal [[:start, 'TASK-42']], o1.events
    assert_equal [[:start, 'TASK-42']], o2.events
  end

  def test_run_finished_forwards_exit_code_to_every_observer
    o1 = observed
    o2 = observed
    fanout = Letsdo::Metrics::Fanout.new(o1, o2)
    fanout.run_finished(0)

    assert_equal [[:finish, 0]], o1.events
    assert_equal [[:finish, 0]], o2.events
  end

  def test_run_finished_nil_forwards_nil_exit_code
    o1 = observed
    fanout = Letsdo::Metrics::Fanout.new(o1)
    fanout.run_finished(nil)

    assert_equal [[:finish, nil]], o1.events
  end

  def test_run_finished_no_argument_is_nil
    o1 = observed
    fanout = Letsdo::Metrics::Fanout.new(o1)
    fanout.run_finished

    assert_equal [[:finish, nil]], o1.events
  end

  private

  def observed
    # Returns an object that records all forwarded calls as [method, arg] pairs.
    Object.new.tap do |obj|
      events = []
      obj.define_singleton_method(:events) { events }
      obj.define_singleton_method(:provider_result) { |count| events << [:provider, count] }
      obj.define_singleton_method(:run_started) { |task| events << [:start, task] }
      obj.define_singleton_method(:run_finished) { |exit_code| events << [:finish, exit_code] }
    end
  end
end
