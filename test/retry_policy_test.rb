# frozen_string_literal: true

require_relative 'test_helper'

class RetryPolicyTest < Minitest::Test
  def test_exponential_backoff_grows_until_default_cap
    policy = policy_with_clock(1000, base: 10)

    assert_equal 1010, policy.record_failure('TASK-1')[:cool_until]
    assert_equal 1020, policy.record_failure('TASK-1')[:cool_until]
    assert_equal 1040, policy.record_failure('TASK-1')[:cool_until]
    assert_equal 1080, policy.record_failure('TASK-1')[:cool_until]
  end

  def test_backoff_is_capped_at_the_configured_maximum
    policy = policy_with_clock(1000, base: 10, cap: 30)

    assert_equal 1010, policy.record_failure('TASK-1')[:cool_until]
    assert_equal 1020, policy.record_failure('TASK-1')[:cool_until]
    assert_equal 1030, policy.record_failure('TASK-1')[:cool_until]
    assert_equal 1030, policy.record_failure('TASK-1')[:cool_until]
  end

  def test_cooldown_uses_explicit_now_and_expires_at_deadline
    policy = policy_with_clock(1000, base: 10)

    policy.record_failure('TASK-1')
    assert policy.cooldown?('TASK-1', 1009)
    refute policy.cooldown?('TASK-1', 1010)
    # An explicit now of zero must be honored (not replaced by the clock).
    assert policy.cooldown?('TASK-1', 0)
  end

  def test_give_up_starts_after_max_retries
    policy = policy_with_clock(1000, max_retries: 3)

    2.times { policy.record_failure('TASK-1') }
    refute policy.gave_up?('TASK-1')
    policy.record_failure('TASK-1')
    assert policy.gave_up?('TASK-1')
  end

  def test_success_and_reset_clear_failure_state
    policy = policy_with_clock(1000, base: 10)
    policy.record_failure('TASK-1')

    policy.record_success('TASK-1')
    assert_equal 0, policy.failures('TASK-1')
    refute policy.cooldown?('TASK-1', 0)

    policy.record_failure('TASK-2')
    policy.reset
    assert_equal 0, policy.failures('TASK-2')
    assert_nil policy.earliest_cooldown(0)
  end

  def test_earliest_cooldown_returns_the_nearest_future_deadline
    policy = policy_with_clock(1000, base: 10)
    policy.record_failure('TASK-1')
    policy.record_failure('TASK-2')

    assert_equal 1010, policy.earliest_cooldown(0)
    assert_nil policy.earliest_cooldown(1020)
  end

  def policy_with_clock(now, **options)
    Letsdo::RetryPolicy.new(clock: FakeClock.new(now), **options)
  end

  class FakeClock
    attr_reader :now

    def initialize(now)
      @now = now
    end

    def call
      @now
    end
  end
end
