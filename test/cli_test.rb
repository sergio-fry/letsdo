# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'tempfile'
require 'json'

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

  def test_missing_prompt_run_still_runs_the_loop
    env = fake_backlog_env(scenario: 'empty', extra: { 'LETSDO_PI_COMMAND' => fake_pi })
    code = run_cli(['nosuch'], prompts: { 'developer' => 'x' }, env: env, sleeper: stop_on_first_wait)

    assert_equal 0, code
    # The run proceeded into the loop (it waited for tasks) and exited cleanly
    # on the stop — it did not fail before the loop as the old unknown-agent
    # path did.
    assert_includes @err.string, 'letsdo: no open tasks for nosuch'
  end

  def test_missing_prompt_notifies_once_with_path_and_hint
    env = fake_backlog_env(scenario: 'empty', extra: { 'LETSDO_PI_COMMAND' => fake_pi })
    run_cli(['nosuch'], prompts: { 'developer' => 'x' }, env: env, sleeper: stop_on_first_wait)

    path_line = 'letsdo: no prompt for nosuch at '
    hint_line = 'letsdo: using the built-in default prompt (create a prompt file with \'letsdo nosuch --init\')'
    # Both lines appear exactly once, and name the exact path checked.
    assert_equal 1, @err.string.scan(path_line).size
    assert_equal 1, @err.string.scan(hint_line).size
    assert_match %r{letsdo: no prompt for nosuch at (?:/.*)?/agents/nosuch\.md\n}, @err.string
  end

  def test_missing_prompt_notification_precedes_first_loop_message
    env = fake_backlog_env(scenario: 'empty', extra: { 'LETSDO_PI_COMMAND' => fake_pi })
    run_cli(['nosuch'], prompts: { 'developer' => 'x' }, env: env, sleeper: stop_on_first_wait)

    notify_at = @err.string.index('letsdo: no prompt for nosuch at ')
    loop_at = @err.string.index('letsdo: no open tasks for nosuch')
    refute_nil notify_at
    refute_nil loop_at
    assert_operator notify_at, :<, loop_at
  end

  def test_existing_prompt_prints_no_notification
    code = run_developer(scenario: 'empty')

    assert_equal 0, code
    refute_includes @err.string, 'letsdo: no prompt for developer'
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

  # Stop summary (TASK-69): plain mode prints it to stderr after the loop's
  # own 'letsdo: stopped' line, so the plain stream stays otherwise identical.
  def test_stop_summary_is_printed_after_stopped
    code = run_developer(count: 1)

    assert_equal 0, code
    assert_includes @err.string, 'letsdo: session: 1 done, 0 failed, 0 interrupted'
    stopped = @err.string.index('letsdo: stopped')
    summary = @err.string.index('letsdo: session:')
    assert_operator summary, :>, stopped, 'summary must follow the stopped line'
  end

  # LETSDO_METRICS_FILE (TASK-69): the recorder appends one JSON line per
  # event to the configured path.
  def test_metrics_file_records_jsonl_events
    Tempfile.create('letsdo-metrics') do |file|
      assert_equal 0, run_developer(count: 1, extra: { 'LETSDO_METRICS_FILE' => file.path })
      events = metrics_events(file.path)
      names = events.map { |event| event['event'] }

      assert_equal 'session_start', names.first
      assert_includes names, 'run_finished'
      assert_equal 'session_stop', names.last
    end
  end

  def metrics_events(path)
    File.read(path).lines.map { |line| JSON.parse(line) }
  end

  def test_injected_sleeper_is_honored_with_the_backlog_watcher
    # The CLI builds a default backlog watcher for the loop; an injected
    # control/stop sleeper must still win over the watcher idle path so the
    # loop stops instead of hanging in the watcher's wait (TASK-84).
    code = run_developer(scenario: 'empty')

    assert_equal 0, code
    assert_includes @err.string, 'letsdo: no open tasks for developer'
  end

  def test_missing_prompt_run_still_executes_tasks_with_default_prompt
    with_argv_file('FAKE_PI_ARGV_FILE') do |path|
      env = fake_backlog_env(scenario: 'open', count: 2, extra: { 'LETSDO_PI_COMMAND' => fake_pi })
      code = run_cli(['nosuch'], prompts: {}, env: env, sleeper: stop_on_first_wait)

      assert_equal 0, code
      # The prompt text is multi-line, so the argv record spans newlines and
      # puts appends no separator after it: assert the exact two records.
      record = "--mode|json|#{Letsdo::DefaultPrompt::TEXT}"
      assert_equal record * 2, File.read(path)
    end
  end

  def test_agent_exit_code_is_logged_but_not_propagated
    with_env('FAKE_PI_EXIT' => '7') do
      code = run_developer(count: 1)
      assert_equal 0, code
      assert_includes @err.string, 'letsdo: developer exited with code 7'
    end
  end

  def test_missing_backend_binary_exits_two_with_clear_message
    env = fake_backlog_env(scenario: 'open',
                           extra: { 'LETSDO_PI_COMMAND' => 'nonexistent_pi_xyz' })
    code = run_cli(['developer'], prompts: developer_prompts, env: env,
                                  sleeper: stop_on_first_wait)

    assert_equal 2, code
    assert_includes @err.string, 'letsdo: cannot start AI backend'\
                                " 'nonexistent_pi_xyz'"
    refute_includes @err.string, 'backtrace', 'must fail cleanly, no Ruby backtrace'
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
    tty_out = FakeTtyOut.new
    code = with_project(developer_prompts) do |root|
      Letsdo::CLI.run(['developer'], env: tui_env_hash(root, extra.dup),
                                     stdout: tty_out, stderr: @err,
                                     stdin: FakeTtyIn.new(keys), sleeper: sleeper)
    end
    [code, tty_out]
  end

  def test_tui_engages_with_real_terminals_and_quits_cleanly
    code, tty_out = run_tui('q', { count: 2 })

    assert_equal 0, code
    assert_includes tty_out.string, "\e[?1049h"
    assert_includes tty_out.string, "\e[?1049l"
    assert_includes tty_out.string, 'letsdo · developer (@developer)'
    # The stop summary prints after the terminal is restored (TASK-69).
    assert_includes @err.string, 'letsdo: session:'
  end

  # TUI quit raises Letsdo::Stopped in the main thread (TASK-79 regression):
  # when that lands while a backlog child is being captured, the child's
  # pipe readers must not dump "stream closed in another thread" noise.
  def test_tui_quit_prints_no_open3_thread_noise
    code, tty_out, dumped = capture_tui_run('q', { count: 2 })

    assert_equal 0, code
    assert_includes tty_out.string, "\e[?1049h"
    assert_includes @err.string, 'letsdo: session:'
    refute_includes dumped, 'stream closed'
    refute_includes dumped, 'terminated with exception'
  end

  # Runs the TUI scenario with the process $stderr captured — thread dumps
  # from report_on_exception go there, not to the injected @err stream.
  def capture_tui_run(keys, extra = {})
    real_stderr = $stderr
    captured = StringIO.new
    $stderr = captured
    result = run_tui(keys, extra)
    [*result, captured.string]
  ensure
    $stderr = real_stderr
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
    tty_out = FakeTtyOut.new
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

# --init scaffold command (TASK-44): creates agents/<name>.md with the
# starter default prompt, never runs the agent.
class CliInitTest < CliTest
  # Runs the CLI and yields (exit_code, root) while the temp project is
  # still alive — file assertions must happen inside the block.
  def with_run_init(argv, prompts: {}, env: {}, sleeper: nil)
    with_project(prompts) do |root|
      code = Letsdo::CLI.run(argv, env: env.merge('LETSDO_ROOT' => root),
                                   stdout: @out, stderr: @err, sleeper: sleeper)
      yield code, root
    end
  end

  def prompt_file(root, name)
    File.join(root, 'agents', "#{name}.md")
  end

  def test_init_creates_the_prompt_file_name_first
    with_run_init(['developer', '--init']) do |code, root|
      assert_equal 0, code
      assert_equal Letsdo::DefaultPrompt::TEXT, File.read(prompt_file(root, 'developer'))
      assert_equal "created #{File.join(File.expand_path(root), 'agents', 'developer.md')}\n",
                   @out.string
      assert_empty @err.string
    end
  end

  def test_init_flag_first_form_behaves_identically
    with_run_init(['--init', 'developer']) do |code, root|
      assert_equal 0, code
      assert_equal Letsdo::DefaultPrompt::TEXT, File.read(prompt_file(root, 'developer'))
      assert_equal "created #{File.join(File.expand_path(root), 'agents', 'developer.md')}\n",
                   @out.string
      assert_empty @err.string
    end
  end

  def test_init_does_not_spawn_pi
    with_argv_file('FAKE_PI_ARGV_FILE') do |path|
      with_run_init(['developer', '--init'], env: { 'FAKE_PI_ARGV_FILE' => path }) do |code,|
        assert_equal 0, code
        assert_empty File.read(path)
      end
    end
  end

  def test_init_never_overwrites_an_existing_file
    with_run_init(['developer', '--init'], prompts: { 'developer' => 'custom prompt' }) do |code, root|
      assert_equal 1, code
      assert_equal 'custom prompt', File.read(prompt_file(root, 'developer'))
      assert_includes @err.string, "letsdo: agents/developer.md already exists\n"
      assert_empty @out.string
    end
  end

  # Runs 'letsdo <name> --init' and asserts the scaffold is refused:
  # exit 1, "letsdo: invalid agent name: <name>" on stderr and no file
  # created anywhere (path-safety).
  def refute_init_creates(name)
    out = StringIO.new
    err = StringIO.new
    with_project({}) do |root|
      code = Letsdo::CLI.run([name, '--init'], env: { 'LETSDO_ROOT' => root },
                                               stdout: out, stderr: err)
      assert_equal 1, code, "#{name.inspect} should exit 1"
      assert_includes err.string, "letsdo: invalid agent name: #{name}\n"
      assert_empty Dir.glob(File.join(root, '**', '*.md')), "#{name.inspect} created a file"
    end
  end

  def test_init_refuses_unsafe_names
    %w[a/b a\\b ../x . ..].each { |name| refute_init_creates(name) }
  end

  def test_init_without_a_name_prints_usage
    with_run_init(['--init']) do |code,|
      assert_equal 1, code
      assert_includes @err.string, 'Usage: letsdo <agent_name>'
    end
  end

  def test_plain_name_run_does_not_trigger_init
    env = fake_backlog_env(scenario: 'empty', extra: { 'LETSDO_PI_COMMAND' => fake_pi })
    with_run_init(['developer'], prompts: { 'developer' => 'You are a developer.' },
                                 env: env, sleeper: stop_on_first_wait) do |code, root|
      assert_equal 0, code
      assert_equal 'You are a developer.', File.read(prompt_file(root, 'developer'))
      refute_includes @out.string, 'created '
    end
  end
end
