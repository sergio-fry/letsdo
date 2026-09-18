# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# `letsdo doctor` environment self-check (TASK-71): one status line per
# check, an actionable hint on every FAIL/WARN, exit 0 unless a FAIL line is
# present. Fixtures use a temporary project root and fake pi/backlog
# commands injected via the env, so no real backend is ever started.
#
# DoctorTest holds the shared harness (temp project root, env builder,
# assertion helpers); the scenario classes below are split so each stays
# within the class-length limit, mirroring the CliTest layout.
class DoctorTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  def run_doctor(env)
    Letsdo::CLI.run(['doctor'], env: env, stdout: @out, stderr: @err)
  end

  def fake_backlog_script
    File.expand_path('fixtures/fake_backlog', __dir__)
  end

  # A complete, healthy project root: backlog/tasks + AGENTS.md + one prompt.
  def healthy_root
    Dir.mktmpdir('letsdo-doctor') do |root|
      FileUtils.mkdir_p(File.join(root, 'backlog', 'tasks'))
      FileUtils.mkdir_p(File.join(root, 'agents'))
      File.write(File.join(root, 'agents', 'developer.md'), 'x')
      File.write(File.join(root, 'AGENTS.md'), '# instructions')
      yield root
    end
  end

  def healthy_env(root, extra = {})
    { 'LETSDO_ROOT' => root, 'LETSDO_PI_COMMAND' => fake_pi,
      'LETSDO_BACKLOG_COMMAND' => fake_backlog_script }.merge(extra)
  end

  def assert_line(text)
    assert_includes @out.string, text
  end

  def assert_ok_lines(root)
    assert_line "[ OK ] ruby #{RUBY_VERSION} (>= 3.3)"
    assert_line "[ OK ] pi command found: #{fake_pi}"
    assert_line "[ OK ] backlog command found: #{fake_backlog_script}"
    assert_line '[ OK ] assignee names are stored bare (canonical)'
    assert_line "[ OK ] project root #{root} has backlog/tasks/"
    assert_line "[ OK ] AGENTS.md present at #{File.join(root, 'AGENTS.md')}"
    assert_line '[ OK ] agents/ present with 1 prompt(s)'
    assert_line '[INFO] stdout is not a TTY - plain mode'
  end
end

# The healthy path: every check passes, plus the TTY/mode INFO line.
class DoctorReportTest < DoctorTest
  def test_everything_present_reports_all_ok_and_exits_zero
    healthy_root do |root|
      code = run_doctor(healthy_env(root))

      assert_equal 0, code
      assert_ok_lines(root)
      refute_includes @out.string, '[FAIL]'
      assert_empty @err.string
    end
  end

  def test_bare_command_is_resolved_through_config_path
    Dir.mktmpdir('letsdo-bin') do |bin|
      File.write(File.join(bin, 'mypi'), "#!/bin/sh\nexit 0\n")
      File.chmod(0o755, File.join(bin, 'mypi'))
      healthy_root do |root|
        code = run_doctor(healthy_env(root, 'LETSDO_PI_COMMAND' => 'mypi', 'PATH' => bin))

        assert_equal 0, code
        assert_line '[ OK ] pi command found: mypi'
      end
    end
  end

  def test_tty_stdout_reports_tui_mode
    tty = FakeTtyOut.new
    healthy_root do |root|
      code = Letsdo::CLI.run(['doctor'], env: healthy_env(root), stdout: tty, stderr: @err)

      assert_equal 0, code
      assert_includes tty.string, '[INFO] stdout is a TTY - TUI mode'
    end
  end

  # `doctor` is reserved: it never launches an agent, whatever the prompt
  # files in agents/ are called.
  def test_doctor_never_launches_an_agent
    Dir.mktmpdir('letsdo-argv') do |dir|
      argv_file = File.join(dir, 'argv')
      healthy_root do |root|
        code = run_doctor(healthy_env(root, 'FAKE_PI_ARGV_FILE' => argv_file))

        assert_equal 0, code
        refute File.exist?(argv_file), 'doctor must not run pi'
      end
    end
  end
end

# FAIL/WARN scenarios and CLI-argument priority.
class DoctorFailureTest < DoctorTest
  def test_pi_missing_is_fail_with_hint_and_exit_one
    healthy_root do |root|
      code = run_doctor(healthy_env(root, 'LETSDO_PI_COMMAND' => 'letsdo_nope_pi'))

      assert_equal 1, code
      assert_line('[FAIL] pi command not found: letsdo_nope_pi' \
                  ' - install pi or set LETSDO_PI_COMMAND')
    end
  end

  def test_backlog_missing_is_fail_with_hint_and_exit_one
    healthy_root do |root|
      code = run_doctor(healthy_env(root, 'LETSDO_BACKLOG_COMMAND' => 'letsdo_nope_backlog'))

      assert_equal 1, code
      assert_line('[FAIL] backlog command not found: letsdo_nope_backlog' \
                  ' - install backlog or set LETSDO_BACKLOG_COMMAND')
    end
  end

  def test_missing_backlog_tasks_is_fail_with_hint_and_exit_one
    Dir.mktmpdir('letsdo-doctor') do |root|
      FileUtils.mkdir_p(File.join(root, 'agents'))
      File.write(File.join(root, 'agents', 'developer.md'), 'x')
      File.write(File.join(root, 'AGENTS.md'), '# instructions')

      code = run_doctor(healthy_env(root))

      assert_equal 1, code
      assert_line("[FAIL] project root #{root} has no backlog/tasks/" \
                  ' - run `backlog init` or set LETSDO_ROOT to a Backlog.md project')
    end
  end

  def test_missing_agents_md_is_warn_with_hint_but_exits_zero
    healthy_root do |root|
      File.delete(File.join(root, 'AGENTS.md'))

      code = run_doctor(healthy_env(root))

      assert_equal 0, code
      assert_line("[WARN] no AGENTS.md at #{File.join(root, 'AGENTS.md')}" \
                  ' - add AGENTS.md with the project instructions for agents')
      refute_includes @out.string, '[FAIL]'
    end
  end

  def test_missing_agents_dir_is_warn_with_init_hint_but_exits_zero
    healthy_root do |root|
      FileUtils.rm_rf(File.join(root, 'agents'))

      code = run_doctor(healthy_env(root))

      assert_equal 0, code
      assert_line("[WARN] agents/ missing or empty at #{File.join(root, 'agents')}" \
                  ' - create an agent prompt with `letsdo <name> --init`')
      refute_includes @out.string, '[FAIL]'
    end
  end

  # `--version`/`--help` keep priority, and unknown options still exit 1.
  def test_version_keeps_priority_over_doctor
    assert_equal 0, Letsdo::CLI.run(['--version'], env: {}, stdout: @out, stderr: @err)
    assert_equal "#{Letsdo::VERSION}\n", @out.string
  end

  def test_help_keeps_priority_over_doctor
    assert_equal 0, Letsdo::CLI.run(['--help'], env: {}, stdout: @out, stderr: @err)
    assert_includes @out.string, 'Usage: letsdo <agent_name>'
  end

  def test_unknown_option_still_exits_one
    code = Letsdo::CLI.run(['--badopt'], env: {}, stdout: @out, stderr: @err)

    assert_equal 1, code
    assert_includes @err.string, 'letsdo: unknown option: --badopt'
  end
end

# Assignee-name convention check (TASK-96): the tracker stores bare
# names; a legacy '@'-prefixed override or stored assignee is a WARN,
# an unreadable backlog skips the check as INFO.
class DoctorAssigneeTest < DoctorTest
  def test_legacy_at_prefixed_stored_assignees_warn
    healthy_root do |root|
      code = run_doctor(healthy_env(root, 'FAKE_BACKLOG_SCENARIO' => 'assignees'))

      assert_equal 0, code, 'WARN must not fail the report'
      assert_line("[WARN] tasks store legacy @-prefixed assignee(s): '@developer'" \
                  ' - reassign them to bare names: backlog task edit <ID> -a <name>')
    end
  end

  def test_at_prefixed_handle_override_warns_before_the_stored_scan
    healthy_root do |root|
      code = run_doctor(healthy_env(root, 'AGENT_ASSIGNEE_HANDLE' => '@legacy'))

      assert_equal 0, code
      assert_line("[WARN] AGENT_ASSIGNEE_HANDLE '@legacy' carries the legacy '@' prefix" \
                  ' - set it to the bare name: AGENT_ASSIGNEE_HANDLE=legacy')
    end
  end

  def test_unreadable_backlog_skips_the_check_as_info
    healthy_root do |root|
      code = run_doctor(healthy_env(root, 'FAKE_BACKLOG_SCENARIO' => 'fail'))

      assert_equal 0, code, 'INFO must not fail the report'
      assert_line '[INFO] assignee names not checked - backlog task list failed'
    end
  end
end
