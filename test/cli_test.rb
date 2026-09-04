# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'tempfile'

# A fake terminal stream: reports tty? true, buffers writes like StringIO.
class CliFakeTtyOut
  attr_reader :io

  def initialize
    @io = StringIO.new
  end

  def tty?
    true
  end

  def write(text)
    @io.write(text)
  end

  def puts(*args)
    @io.puts(*args)
  end

  def flush
    @io.flush
  end

  def string
    @io.string
  end
end

# A fake keyboard: reports tty? true and serves the scripted bytes.
class CliFakeTtyIn
  def initialize(bytes)
    @io = StringIO.new(bytes)
  end

  def tty?
    true
  end

  def eof?
    @io.eof?
  end

  def getc
    @io.getc
  end

  def wait_readable(_timeout)
    @io.eof? ? nil : true
  end

  def raw(&block)
    block.call
  end

  def noecho(&block)
    block.call
  end
end

# CLI tests share stdout/stderr StringIOs and a fake-backlog env builder.
# Each concern below is its own class so every class stays within the
# default length limits.
class CliTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  def run_cli(argv, prompts:, env: {}, sleeper: nil)
    with_project(prompts) do |root|
      Letsdo::CLI.run(argv, env: env.merge('LETSDO_ROOT' => root), stdout: @out, stderr: @err,
                            sleeper: sleeper)
    end
  end

  def stop_on_first_wait
    ->(_seconds) { throw Letsdo::AgentLoop::STOP }
  end

  def fake_backlog_env(scenario: 'open', count: nil, extra: {})
    env = { 'LETSDO_BACKLOG_COMMAND' => fake_backlog_script, 'FAKE_BACKLOG_SCENARIO' => scenario }
    env['FAKE_BACKLOG_COUNT'] = count.to_s if count
    env['FAKE_BACKLOG_DONE_FILE'] = unique_done_file if scenario == 'open'
    env.merge(extra)
  end

  def unique_done_file
    # Minitest reseeds Kernel.srand per test class; Kernel.rand under that
    # seed reused the same /tmp marker and made later "open" runs empty.
    File.join(Dir.mktmpdir('letsdo-done'), 'marker')
  end

  def fake_backlog_script
    File.expand_path('fixtures/fake_backlog', __dir__)
  end

  def developer_prompts
    { 'developer' => 'You are a developer.' }
  end

  def run_developer(scenario: 'open', count: nil, extra: {})
    env = fake_backlog_env(scenario: scenario, count: count,
                           extra: extra.merge('LETSDO_PI_COMMAND' => fake_pi))
    run_cli(['developer'], prompts: developer_prompts, env: env, sleeper: stop_on_first_wait)
  end

  def with_argv_file(env_key)
    Tempfile.create('argv') do |file|
      with_env(env_key => file.path) { yield file.path }
    end
  end
end

# Usage, version, help, unknown agent/option.
class CliUsageTest < CliTest
  def test_no_args_prints_usage_and_agents
    code = run_cli([], prompts: { 'developer' => 'x', 'looptest' => 'y' })

    assert_equal 1, code
    assert_includes @err.string, 'Usage: letsdo <agent_name>'
    assert_includes @out.string, 'Available agents:'
    assert_includes @out.string, 'developer'
    assert_includes @out.string, 'looptest'
  end

  def test_version_succeeds
    code = run_cli(['--version'], prompts: {})

    assert_equal 0, code
    assert_equal "#{Letsdo::VERSION}\n", @out.string
  end

  def test_short_version_succeeds
    assert_equal 0, run_cli(['-v'], prompts: {})
  end

  def test_help_succeeds
    code = run_cli(['--help'], prompts: {})

    assert_equal 0, code
    assert_includes @out.string, 'Usage: letsdo <agent_name>'
  end

  def test_unknown_option_fails
    code = run_cli(['--badopt'], prompts: {})

    assert_equal 1, code
    assert_includes @err.string, 'letsdo: unknown option: --badopt'
  end

  def test_unknown_agent_prints_error_and_agents
    code = run_cli(['nosuch'], prompts: { 'developer' => 'x', 'looptest' => 'y' })

    assert_equal 1, code
    assert_includes @err.string, 'Unknown agent: nosuch'
    assert_includes @out.string, 'Available agents:'
    assert_includes @out.string, 'developer'
    assert_includes @out.string, 'looptest'
  end

  def test_unknown_agent_fails_before_the_loop
    code = run_cli(['nosuch'], prompts: { 'developer' => 'x' })

    assert_equal 1, code
    assert_includes @err.string, 'Unknown agent: nosuch'
  end
end

# Orchestrator loop via the CLI: tasks, flags, handles, wait interval.
class CliRunTest < CliTest
  def test_open_tasks_are_run_one_per_task
    with_argv_file('FAKE_PI_ARGV_FILE') do |path|
      code = run_developer(count: 3)
      assert_equal 0, code
      assert_equal 3, File.read(path).lines.length
      assert_equal "Hello, world!\n" * 3, @out.string
    end
  end

  def test_without_open_tasks_the_loop_waits
    code = run_developer(scenario: 'empty')

    assert_equal 0, code
    assert_includes @err.string, 'letsdo: no open tasks for developer'
    assert_equal '', @out.string
  end

  def test_agent_exit_code_is_logged_but_not_propagated
    with_env('FAKE_PI_EXIT' => '7') do
      code = run_developer(count: 1)
      assert_equal 0, code
      assert_includes @err.string, 'letsdo: developer exited with code 7'
    end
  end

  def test_known_agent_assembles_output_via_pi
    code = run_developer(count: 1)

    assert_equal 0, code
    assert_equal "Hello, world!\n", @out.string
  end

  def test_flags_from_letsdo_pi_flags_env
    with_argv_file('FAKE_PI_ARGV_FILE') do |path|
      run_developer(count: 1, extra: { 'LETSDO_PI_FLAGS' => '--model m' })
      assert_includes File.read(path), '--mode|json|--model|m|'
    end
  end

  def test_flags_fallback_to_agent_pi_flags_env
    with_argv_file('FAKE_PI_ARGV_FILE') do |path|
      run_developer(count: 1, extra: { 'AGENT_PI_FLAGS' => '--model m' })
      assert_includes File.read(path), '--mode|json|--model|m|'
    end
  end

  def test_assignee_handle_override_env
    with_argv_file('FAKE_BACKLOG_ARGV_FILE') do |path|
      run_developer(count: 1, extra: { 'AGENT_ASSIGNEE_HANDLE' => '@someone' })
      assert_includes File.read(path), '--assignee|@someone|'
    end
  end

  def test_wait_seconds_from_env
    code = run_developer(scenario: 'empty', extra: { 'LETSDO_WAIT_SECONDS' => '3.5' })

    assert_equal 0, code
    assert_includes @err.string, 'retrying in 3.5s'
  end
end

# TUI mode selection (TASK-42): TTY + TERM, pause-then-quit.
class CliTuiTest < CliTest
  def tui_env_hash(root, extra)
    count = extra.delete(:count) || 1
    term = extra.delete(:term) || 'xterm-256color'
    fake_backlog_env(count: count, extra: {
      'LETSDO_ROOT' => root, 'TERM' => term,
      'LETSDO_PI_COMMAND' => fake_pi
    }.merge(extra))
  end

  def run_tui(keys, extra = {}, sleeper: nil)
    tty_out = CliFakeTtyOut.new
    code = with_project(developer_prompts) do |root|
      Letsdo::CLI.run(['developer'], env: tui_env_hash(root, extra.dup),
                                     stdout: tty_out, stderr: @err,
                                     stdin: CliFakeTtyIn.new(keys), sleeper: sleeper)
    end
    [code, tty_out]
  end

  def test_tui_engages_with_real_terminals_and_quits_cleanly
    code, tty_out = run_tui('q', { count: 2 })

    assert_equal 0, code
    assert_includes tty_out.string, "\e[?1049h"
    assert_includes tty_out.string, "\e[?1049l"
    assert_includes tty_out.string, 'letsdo · developer (@developer)'
    assert_empty @err.string
  end

  def test_tui_not_engaged_when_stdout_is_not_a_tty
    code = run_developer(count: 1, extra: { 'TERM' => 'xterm' })

    assert_equal 0, code
    assert_equal "Hello, world!\n", @out.string
    refute_includes @out.string, "\e[?1049h"
  end

  def test_tui_not_engaged_when_term_is_dumb
    code, tty_out = run_tui('q', { count: 1, term: 'dumb' }, sleeper: stop_on_first_wait)

    assert_equal 0, code
    assert_equal "Hello, world!\n", tty_out.string
    refute_includes tty_out.string, "\e[?1049h"
  end

  def test_tui_not_engaged_when_stdin_is_not_a_tty
    tty_out = CliFakeTtyOut.new
    code = with_project(developer_prompts) do |root|
      Letsdo::CLI.run(['developer'],
                      env: tui_env_hash(root, count: 1, term: 'xterm'),
                      stdout: tty_out, stderr: @err, stdin: StringIO.new('q'),
                      sleeper: stop_on_first_wait)
    end

    assert_equal 0, code
    assert_equal "Hello, world!\n", tty_out.string
    refute_includes tty_out.string, "\e[?1049h"
  end

  def test_tui_pause_then_quit_terminates_the_pi_cleanly
    code, tty_out = run_tui('pq', { count: 1, 'FAKE_PI_SLEEP' => '300' })

    assert_equal 0, code
    assert_includes tty_out.string, "\e[?1049h"
    assert_includes tty_out.string, "\e[?1049l"
  end
end
