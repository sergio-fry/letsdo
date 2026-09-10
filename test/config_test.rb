# frozen_string_literal: true

require_relative 'test_helper'

# Letsdo::Config reads every LETSDO_*/AGENT_* variable with the defaults and
# precedence that used to be spread across CLI, the Pi backend and AgentLoop.
class ConfigTest < Minitest::Test
  def config(env)
    Letsdo::Config.new(env: env)
  end

  def test_root_defaults_to_cwd
    assert_equal Dir.pwd, config({}).root
  end

  def test_root_from_env
    assert_equal '/tmp/x', config('LETSDO_ROOT' => '/tmp/x').root
  end

  def test_pi_flags_split_on_whitespace
    assert_equal ['--model', 'm'], config('LETSDO_PI_FLAGS' => '--model m').pi_flags
  end

  def test_pi_flags_fall_back_to_agent_pi_flags
    assert_equal ['--model', 'm'], config('AGENT_PI_FLAGS' => '--model m').pi_flags
  end

  def test_pi_flags_letsdo_wins_over_agent
    assert_equal ['--a'], config('LETSDO_PI_FLAGS' => '--a', 'AGENT_PI_FLAGS' => '--b').pi_flags
  end

  def test_pi_flags_empty_when_unset
    assert_equal [], config({}).pi_flags
  end

  def test_assignee_handle_defaults_to_name
    assert_equal '@dev', config({}).assignee_handle('dev')
  end

  def test_assignee_handle_override
    assert_equal '@x', config('AGENT_ASSIGNEE_HANDLE' => '@x').assignee_handle('dev')
  end

  def test_assignee_handle_blank_override_falls_back
    assert_equal '@dev', config('AGENT_ASSIGNEE_HANDLE' => '   ').assignee_handle('dev')
  end

  def test_wait_seconds_defaults_to_ten
    assert_equal 10.0, config({}).wait_seconds
  end

  def test_wait_seconds_from_env
    assert_equal 3.5, config('LETSDO_WAIT_SECONDS' => '3.5').wait_seconds
  end

  def test_wait_seconds_fall_back_to_agent
    assert_equal 4.0, config('AGENT_WAIT_SECONDS' => '4').wait_seconds
  end

  def test_wait_seconds_invalid_falls_back_to_default
    assert_equal 10.0, config('LETSDO_WAIT_SECONDS' => 'not-a-number').wait_seconds
  end

  def test_pi_command_default
    assert_equal 'pi', config({}).pi_command
  end

  def test_pi_command_override
    assert_equal '/x/pi', config('LETSDO_PI_COMMAND' => '/x/pi').pi_command
  end

  def test_backlog_command_default
    assert_equal 'backlog', config({}).backlog_command
  end

  def test_backlog_command_override
    assert_equal 'bl', config('LETSDO_BACKLOG_COMMAND' => 'bl').backlog_command
  end

  def test_provider_defaults_to_backlog
    assert_equal 'backlog', config({}).provider
  end

  def test_provider_override
    assert_equal 'jira', config('LETSDO_PROVIDER' => 'jira').provider
  end

  def test_provider_empty_falls_back_to_default
    assert_equal 'backlog', config('LETSDO_PROVIDER' => '').provider
  end

  def test_provider_whitespace_falls_back_to_default
    assert_equal 'backlog', config('LETSDO_PROVIDER' => '   ').provider
  end

  def test_backend_defaults_to_pi
    assert_equal 'pi', config({}).backend
  end

  def test_backend_override
    assert_equal 'claude', config('LETSDO_BACKEND' => 'claude').backend
  end

  def test_backend_empty_falls_back_to_default
    assert_equal 'pi', config('LETSDO_BACKEND' => '').backend
  end

  def test_backend_whitespace_falls_back_to_default
    assert_equal 'pi', config('LETSDO_BACKEND' => '   ').backend
  end

  def test_debug_disabled_by_default
    refute config({}).debug?
  end

  def test_debug_enabled_by_one
    assert config('LETSDO_DEBUG' => '1').debug?
  end

  def test_debug_disabled_for_other_values
    refute config('LETSDO_DEBUG' => 'true').debug?
  end
end

class ConfigRetryEnvTest < Minitest::Test
  def config(env)
    Letsdo::Config.new(env: env)
  end

  def test_max_retries_defaults_to_three
    assert_equal 3, config({}).max_retries
  end

  def test_max_retries_from_env
    assert_equal 5, config('LETSDO_MAX_RETRIES' => '5').max_retries
  end

  def test_max_retries_invalid_falls_back_to_three
    assert_equal 3, config('LETSDO_MAX_RETRIES' => 'not-a-number').max_retries
  end

  def test_retry_base_defaults_to_wait_seconds
    assert_equal 10.0, config({}).retry_base
  end

  def test_retry_base_from_env
    assert_equal 2.5, config('LETSDO_RETRY_BASE' => '2.5').retry_base
  end

  def test_retry_base_invalid_falls_back_to_wait_seconds
    assert_equal 10.0, config('LETSDO_RETRY_BASE' => 'not-a-number').retry_base
  end

  def test_retry_cap_defaults_to_three_hundred
    assert_equal 300.0, config({}).retry_cap
  end

  def test_retry_cap_from_env
    assert_equal 600.0, config('LETSDO_RETRY_CAP' => '600').retry_cap
  end

  def test_retry_cap_invalid_falls_back_to_three_hundred
    assert_equal 300.0, config('LETSDO_RETRY_CAP' => 'not-a-number').retry_cap
  end
end
