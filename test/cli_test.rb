# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require "tempfile"

class CliTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  # Запускает Letsdo::CLI с тестовым окружением (root = временный проект).
  def run_cli(argv, prompts:, env: {})
    with_project(prompts) do |root|
      Letsdo::CLI.run(argv, env: env.merge("LETSDO_ROOT" => root), stdout: @out, stderr: @err)
    end
  end

  def test_no_args_prints_usage_and_agents_exit_1
    code = run_cli([], prompts: { "developer" => "x", "looptest" => "y" })

    assert_equal 1, code
    assert_includes @err.string, "Использование: letsdo <имя_агента>"
    assert_includes @out.string, "Доступные агенты:"
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
    assert_includes @out.string, "Использование: letsdo <имя_агента>"
  end

  def test_unknown_option_exit_1
    code = run_cli(["--badopt"], prompts: {})

    assert_equal 1, code
    assert_includes @err.string, "letsdo: неизвестная опция: --badopt"
  end

  def test_unknown_agent_prints_error_and_agents_exit_1
    code = run_cli(["nosuch"], prompts: { "developer" => "x", "looptest" => "y" })

    assert_equal 1, code
    assert_includes @err.string, "Неизвестный агент: nosuch"
    assert_includes @out.string, "Доступные агенты:"
    assert_includes @out.string, "developer"
    assert_includes @out.string, "looptest"
  end

  def test_known_agent_returns_exit_code_of_pi
    old = ENV["FAKE_PI_EXIT"]
    ENV["FAKE_PI_EXIT"] = "7"
    begin
      code = run_cli(["developer"], prompts: { "developer" => "Ты разработчик." },
                     env: { "LETSDO_PI_COMMAND" => fake_pi })
    ensure
      ENV["FAKE_PI_EXIT"] = old
    end

    assert_equal 7, code
  end

  def test_known_agent_assembles_output_via_pi
    code = run_cli(["developer"], prompts: { "developer" => "Ты разработчик." },
                   env: { "LETSDO_PI_COMMAND" => fake_pi })

    assert_equal 0, code
    assert_equal "Привет, мир!\n", @out.string
  end

  def test_flags_from_letsdo_pi_flags_env
    Tempfile.create("fake_pi_argv") do |file|
      old = ENV["FAKE_PI_ARGV_FILE"]
      ENV["FAKE_PI_ARGV_FILE"] = file.path
      begin
        run_cli(["developer"], prompts: { "developer" => "Ты разработчик." },
                 env: { "LETSDO_PI_COMMAND" => fake_pi, "LETSDO_PI_FLAGS" => "--model m" })
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
        run_cli(["developer"], prompts: { "developer" => "Ты разработчик." },
                 env: { "LETSDO_PI_COMMAND" => fake_pi, "AGENT_PI_FLAGS" => "--model m" })
      ensure
        ENV["FAKE_PI_ARGV_FILE"] = old
      end

      assert_includes File.read(file.path), "--mode|json|--model|m|"
    end
  end
end