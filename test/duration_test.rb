# frozen_string_literal: true

require_relative 'test_helper'

# Letsdo::Duration (TASK-70): the one duration formatter shared by the stop
# summary and the task-time write-back.
class DurationTest < Minitest::Test
  def test_zero
    assert_equal '0s', Letsdo::Duration.format(0)
  end

  def test_seconds_only
    assert_equal '12s', Letsdo::Duration.format(12)
  end

  def test_minutes_and_seconds
    assert_equal '4m 12s', Letsdo::Duration.format(252)
  end

  def test_rounds_to_the_nearest_second
    assert_equal '5s', Letsdo::Duration.format(4.6)
  end

  def test_negative_clamps_to_zero
    assert_equal '0s', Letsdo::Duration.format(-3)
  end
end
