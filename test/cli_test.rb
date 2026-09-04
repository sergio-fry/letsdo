# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require "tempfile"

class CliTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  # Runs Letsdo::CLI with a test environment (root = a temporary project).
  def run_cli(argv, prompts:, env: {}, sleeper: nil)
    with_project(prompts) do |root|
      Letsdo::CLI.run(argv, env: env.merge("LETSDO_ROOT" => root), stdout: @out, stderr: @err,
                      sleeper: sleeper)
    end
  end

  # A sleeper that makes the orchestrator loop stop on its first wait.
  def stop_on_first_wait
    ->(_seconds) { throw Letsdo::AgentLoop::STOP }
  end

  # The fake backlog command with the scenario/count environment override.
  # The "open" scenario is self-consumed via FAKE_BACKLOG_DONE_FILE: the
  # first call returns the tasks, later calls see the done file and become
  # empty, so the loop reaches its waiting/stop path.
  def fake_backlog_env(scenario: "open", count: nil, extra: {})
    env = { "LETSDO_BACKLOG_COMMAND" => fake_backlog_script, "FAKE_BACKLOG_SCENARIO" => scenario }
    env["FAKE_BACKLOG_COUNT"] = count.to_s if count
    if scenario == "open"
      # A plain path (not a Tempfile): Tempfile finalizers unlink the file
      # on GC, which would wipe the fake_backlog "done" marker mid-test and
      # make the loop see open tasks forever.
      env["FAKE_BACKLOG_DONE_FILE"] =
        File.join(Dir.tmpdir, "fake_backlog_done_#{Process.pid}_#{rand(1_000_000)}")
    end
    env.merge(extra)
  end

  def fake_backlog_script
    File.expand_path("fixtures/fake_backlog", __dir__)
  end

  def test_no_args_prints_usage_and_agents_exit_1
    code = run_cli([], prompts: { "developer" => "x", "looptest" => "y" })

    assert_equal 1, code
    assert_includes @err.string, "Usage: letsdo <agent_name>"
    assert_includes @out.string, "Available agents:"
    assert_includes @out.string, "developer"
    assert_includes @out.string, "looptest"
  end

  def test_version_exit_0
    code = run_cli(["--version"], prompts: {})

    assert_equal 0, code
    assert_equal "#{Letsdo::VERSION}\n", @out.string
  end

  def test_short_version_exit_0
    assert_equal 0, run_cli(["-v"], prompts: {})
  end

  def test_help_exit_0
    code = run_cli(["--help"], prompts: {})

    assert_equal 0, code
    assert_includes @out.string, "Usage: letsdo <agent_name>"
  end

  def test_unknown_option_exit_1
    code = run_cli(["--badopt"], prompts: {})

    assert_equal 1, code
    assert_includes @err.string, "letsdo: unknown option: --badopt"
  end

  def test_unknown_agent_prints_error_and_agents_exit_1
    code = run_cli(["nosuch"], prompts: { "developer" => "x", "looptest" => "y" })

    assert_equal 1, code
    assert_includes @err.string, "Unknown agent: nosuch"
    assert_includes @out.string, "Available agents:"
    assert_includes @out.string, "developer"
    assert_includes @out.string, "looptest"
  end

  def test_open_tasks_are_run_one_per_task
    Tempfile.create("fake_pi_argv") do |file|
      old = ENV["FAKE_PI_ARGV_FILE"]
      ENV["FAKE_PI_ARGV_FILE"] = file.path
      begin
        code = run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                       env: fake_backlog_env(count: 3).merge("LETSDO_PI_COMMAND" => fake_pi),
                       sleeper: stop_on_first_wait)
      ensure
        ENV["FAKE_PI_ARGV_FILE"] = old
      end

      assert_equal 0, code
      assert_equal 3, File.read(file.path).lines.length
      # One agent run per open task: the agent output appears once per run.
      assert_equal "Hello, world!\n" * 3, @out.string
    end
  end

  def test_without_open_tasks_the_loop_waits
    code = run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                   env: fake_backlog_env(scenario: "empty").merge("LETSDO_PI_COMMAND" => fake_pi),
                   sleeper: stop_on_first_wait)

    assert_equal 0, code
    assert_includes @err.string, "letsdo: no open tasks for developer"
    assert_equal "", @out.string
  end

  def test_agent_exit_code_is_logged_but_not_propagated
    old = ENV["FAKE_PI_EXIT"]
    ENV["FAKE_PI_EXIT"] = "7"
    begin
      code = run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                     env: fake_backlog_env(count: 1).merge("LETSDO_PI_COMMAND" => fake_pi),
                     sleeper: stop_on_first_wait)
    ensure
      ENV["FAKE_PI_EXIT"] = old
    end

    assert_equal 0, code
    assert_includes @err.string, "letsdo: developer exited with code 7"
  end

  def test_known_agent_assembles_output_via_pi
    code = run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                   env: fake_backlog_env(count: 1).merge("LETSDO_PI_COMMAND" => fake_pi),
                   sleeper: stop_on_first_wait)

    assert_equal 0, code
    assert_equal "Hello, world!\n", @out.string
  end

  def test_flags_from_letsdo_pi_flags_env
    Tempfile.create("fake_pi_argv") do |file|
      old = ENV["FAKE_PI_ARGV_FILE"]
      ENV["FAKE_PI_ARGV_FILE"] = file.path
      begin
        run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                 env: fake_backlog_env(count: 1).merge("LETSDO_PI_COMMAND" => fake_pi,
                                                       "LETSDO_PI_FLAGS" => "--model m"),
                 sleeper: stop_on_first_wait)
      ensure
        ENV["FAKE_PI_ARGV_FILE"] = old
      end

      assert_includes File.read(file.path), "--mode|json|--model|m|"
    end
  end

  def test_flags_fallback_to_agent_pi_flags_env
    Tempfile.create("fake_pi_argv") do |file|
      old = ENV["FAKE_PI_ARGV_FILE"]
      ENV["FAKE_PI_ARGV_FILE"] = file.path
      begin
        run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                 env: fake_backlog_env(count: 1).merge("LETSDO_PI_COMMAND" => fake_pi,
                                                       "AGENT_PI_FLAGS" => "--model m"),
                 sleeper: stop_on_first_wait)
      ensure
        ENV["FAKE_PI_ARGV_FILE"] = old
      end

      assert_includes File.read(file.path), "--mode|json|--model|m|"
    end
  end

  def test_assignee_handle_override_env
    Tempfile.create("fake_backlog_argv") do |file|
      old = ENV["FAKE_BACKLOG_ARGV_FILE"]
      ENV["FAKE_BACKLOG_ARGV_FILE"] = file.path
      begin
        run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                 env: fake_backlog_env(count: 1).merge("LETSDO_PI_COMMAND" => fake_pi,
                                                       "AGENT_ASSIGNEE_HANDLE" => "@someone"),
                 sleeper: stop_on_first_wait)
      ensure
        ENV["FAKE_BACKLOG_ARGV_FILE"] = old
      end

      assert_includes File.read(file.path), "--assignee|@someone|"
    end
  end

  def test_wait_seconds_from_env
    code = run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                   env: fake_backlog_env(scenario: "empty").merge(
                     "LETSDO_PI_COMMAND" => fake_pi, "LETSDO_WAIT_SECONDS" => "3.5"
                   ),
                   sleeper: stop_on_first_wait)

    assert_equal 0, code
    assert_includes @err.string, "retrying in 3.5s"
  end

  def test_unknown_agent_fails_before_the_loop
    code = run_cli(["nosuch"], prompts: { "developer" => "x" })

    assert_equal 1, code
    assert_includes @err.string, "Unknown agent: nosuch"
  end

  # --- TUI mode selection (TASK-42) -------------------------------------

  # A fake terminal stream: reports tty? true, buffers writes like StringIO.
  class FakeTtyOut
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
  class FakeTtyIn
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

  # The TUI is engaged only with a terminal stdout, a terminal stdin and
  # TERM != dumb. The 'q' key quits the session the same way a stop signal
  # does: pi child terminated, terminal restored, exit 0.
  def test_tui_engages_with_real_terminals_and_quits_cleanly
    tty_out = FakeTtyOut.new
    code = with_project("developer" => "You are a developer.") do |root|
      Letsdo::CLI.run(["developer"],
                      env: fake_backlog_env(count: 2).merge("LETSDO_ROOT" => root,
                                                            "TERM" => "xterm-256color",
                                                            "LETSDO_PI_COMMAND" => fake_pi),
                      stdout: tty_out, stderr: @err, stdin: FakeTtyIn.new("q"))
    end

    assert_equal 0, code
    assert_includes tty_out.string, "\e[?1049h"   # alternate screen entered
    assert_includes tty_out.string, "\e[?1049l"   # ... and restored
    assert_includes tty_out.string, "letsdo · developer (@developer)"
    assert_empty @err.string # service messages went to the TUI log, not stderr
  end

  def test_tui_not_engaged_when_stdout_is_not_a_tty
    code = run_cli(["developer"], prompts: { "developer" => "You are a developer." },
                   env: fake_backlog_env(count: 1).merge("TERM" => "xterm",
                                                         "LETSDO_PI_COMMAND" => fake_pi),
                   sleeper: stop_on_first_wait)

    assert_equal 0, code
    assert_equal "Hello, world!\n", @out.string
    refute_includes @out.string, "\e[?1049h"
  end

  def test_tui_not_engaged_when_term_is_dumb
    tty_out = FakeTtyOut.new
    code = with_project("developer" => "You are a developer.") do |root|
      Letsdo::CLI.run(["developer"],
                      env: fake_backlog_env(count: 1).merge("LETSDO_ROOT" => root,
                                                            "TERM" => "dumb",
                                                            "LETSDO_PI_COMMAND" => fake_pi),
                      stdout: tty_out, stderr: @err, stdin: FakeTtyIn.new("q"),
                      sleeper: stop_on_first_wait)
    end

    assert_equal 0, code
    assert_equal "Hello, world!\n", tty_out.string
    refute_includes tty_out.string, "\e[?1049h"
  end

  def test_tui_not_engaged_when_stdin_is_not_a_tty
    tty_out = FakeTtyOut.new
    code = with_project("developer" => "You are a developer.") do |root|
      Letsdo::CLI.run(["developer"],
                      env: fake_backlog_env(count: 1).merge("LETSDO_ROOT" => root,
                                                            "TERM" => "xterm",
                                                            "LETSDO_PI_COMMAND" => fake_pi),
                      stdout: tty_out, stderr: @err, stdin: StringIO.new("q"),
                      sleeper: stop_on_first_wait)
    end

    assert_equal 0, code
    assert_equal "Hello, world!\n", tty_out.string
    refute_includes tty_out.string, "\e[?1049h"
  end
end