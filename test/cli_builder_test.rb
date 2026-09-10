# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'tempfile'

# Letsdo::CLI::Builder (TASK-54): the wiring half of the CLI. Parsing and
# usage stay in Letsdo::CLI; the builder owns component assembly and the
# plain-vs-TUI decision (stdout/stdin TTY + TERM).
class CliBuilderTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  def stop_on_first_wait
    ->(_seconds) { throw Letsdo::AgentLoop::STOP }
  end

  def builder(root, stdout: @out, stdin: StringIO.new, env: {})
    Letsdo::CLI::Builder.new(env: env.merge('LETSDO_ROOT' => root), stdout: stdout,
                             stderr: @err, stdin: stdin, sleeper: stop_on_first_wait)
  end

  def fake_backlog_env(scenario: 'empty')
    {
      'LETSDO_BACKLOG_COMMAND' => File.expand_path('fixtures/fake_backlog', __dir__),
      'FAKE_BACKLOG_SCENARIO' => scenario,
      'LETSDO_PI_COMMAND' => File.expand_path('fixtures/fake_pi', __dir__)
    }
  end

  # TUI engagement belongs to the builder (TASK-54): stdout TTY && stdin TTY
  # && TERM != dumb choose the TUI path; anything less falls back to plain.
  def tui?(root, stdout:, stdin:, term:)
    builder(root, stdout: stdout, stdin: stdin, env: fake_backlog_env.merge('TERM' => term))
      .send(:tui?)
  end

  def test_engages_with_stdout_stdin_tty_and_real_term
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      assert tui?(root, stdout: FakeTtyOut.new, stdin: FakeTtyIn.new('q'), term: 'xterm')
    end
  end

  def test_not_engaged_when_stdout_is_not_a_tty
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      refute tui?(root, stdout: StringIO.new, stdin: FakeTtyIn.new('q'), term: 'xterm')
    end
  end

  def test_not_engaged_when_stdin_is_not_a_tty
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      refute tui?(root, stdout: FakeTtyOut.new, stdin: StringIO.new, term: 'xterm')
    end
  end

  def test_not_engaged_when_term_is_dumb
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      refute tui?(root, stdout: FakeTtyOut.new, stdin: FakeTtyIn.new('q'), term: 'dumb')
    end
  end

  def test_plain_run_assembles_the_loop_and_exits_cleanly
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      code = builder(root, env: fake_backlog_env).run('developer')

      assert_equal 0, code
      assert_includes @err.string, 'letsdo: no open tasks for developer'
    end
  end

  def tui_builder(root, stdout:, stdin:, env:)
    Letsdo::CLI::Builder.new(env: env.merge('LETSDO_ROOT' => root), stdout: stdout,
                             stderr: @err, stdin: stdin, sleeper: stop_on_first_wait)
  end

  def test_tui_run_engages_through_the_builder
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      tty_out = FakeTtyOut.new
      env = fake_backlog_env.merge('FAKE_BACKLOG_COUNT' => '1', 'TERM' => 'xterm')
      code = tui_builder(root, stdout: tty_out, stdin: FakeTtyIn.new('q'), env: env)
             .run('developer')

      assert_equal 0, code
      assert_includes tty_out.string, "\e[?1049h"
      assert_includes tty_out.string, "\e[?1049l"
      assert_empty @err.string
    end
  end

  def test_run_notifies_once_for_a_missing_prompt
    with_project({}) do |root|
      code = builder(root, env: fake_backlog_env).run('ghost')

      assert_equal 0, code
      assert_equal 1, @err.string.scan('letsdo: no prompt for ghost at ').size
    end
  end
end
