# frozen_string_literal: true

require_relative 'test_helper'

# TASK-90: while a TUI session runs inside tmux the window is labeled with
# the agent name and the previous label is restored on exit. All tmux access
# is stubbed through an injected runner; the title escape goes to an injected
# (fake TTY) stream.
class TuiWindowTitleTest < Minitest::Test
  TMUX = { 'TMUX' => '/tmp/tmux-0/default,123,0', 'TMUX_PANE' => '%7' }.freeze

  def setup
    @stream = FakeTtyOut.new
  end

  def title(env: TMUX, runner: nil)
    Letsdo::Tui::WindowTitle.new(stream: @stream, env: env, runner: runner)
  end

  # The tmux subcommand of a recorded call (the -t target, when present,
  # follows the subcommand).
  def command_of(args)
    args[0]
  end

  # A runner that answers display-message/show-window-options and records
  # every call, so tests can assert the exact tmux command sequence.
  def recording_runner(previous: 'zsh', automatic_rename: '')
    @calls = []
    lambda do |args|
      @calls << args
      case command_of(args)
      when 'display-message' then previous
      when 'show-window-options' then automatic_rename
      else ''
      end
    end
  end

  def test_inside_tmux_on_a_tty_is_active
    assert title.tmux?
  end

  def test_outside_tmux_is_inactive
    refute title(env: {}).tmux?
  end

  def test_a_non_tty_stream_is_inactive
    subject = Letsdo::Tui::WindowTitle.new(stream: StringIO.new, env: TMUX)

    refute subject.tmux?
  end

  def test_install_writes_the_agent_name_as_a_title_escape
    title(runner: recording_runner).install('developer')

    assert_includes @stream.string, "\e]2;developer\a"
  end

  def test_install_renames_the_window_and_disables_automatic_rename
    title(runner: recording_runner).install('developer')

    assert_includes @calls, ['rename-window', '-t', '%7', 'developer']
    assert_includes @calls, ['set-option', '-t', '%7', '-w', 'automatic-rename', 'off']
  end

  def test_install_captures_the_previous_label_before_renaming
    title(runner: recording_runner).install('developer')

    assert_equal ['display-message', '-t', '%7', '-p', "\#{window_name}"], @calls.first
  end

  def test_restore_puts_the_previous_label_back
    subject = title(runner: recording_runner(previous: 'zsh'))
    subject.install('developer')
    subject.restore

    assert_includes @calls, ['rename-window', '-t', '%7', 'zsh']
  end

  def test_restore_re_enables_automatic_rename_when_it_was_explicit
    subject = title(runner: recording_runner(automatic_rename: 'off'))
    subject.install('developer')
    subject.restore

    assert_includes @calls, ['set-option', '-t', '%7', '-w', 'automatic-rename', 'off']
    refute_includes @calls, ['set-option', '-t', '%7', '-w', '-u', 'automatic-rename']
  end

  def test_restore_unsets_automatic_rename_when_it_had_no_explicit_value
    subject = title(runner: recording_runner(automatic_rename: ''))
    subject.install('developer')
    subject.restore

    assert_includes @calls, ['set-option', '-t', '%7', '-w', '-u', 'automatic-rename']
  end

  def test_restore_resets_the_title_escape_to_the_previous_label
    subject = title(runner: recording_runner(previous: 'zsh'))
    subject.install('developer')
    subject.restore

    assert_includes @stream.string, "\e]2;developer\a"
    assert_includes @stream.string, "\e]2;zsh\a"
  end

  def test_restore_without_install_writes_nothing
    title(runner: recording_runner).restore

    assert_empty @stream.string
  end

  def test_outside_tmux_nothing_is_written_and_tmux_is_never_run
    runner = ->(_args) { flunk 'tmux must not be invoked outside tmux' }
    subject = title(env: {}, runner: runner)

    subject.install('developer')
    subject.restore

    assert_empty @stream.string
  end

  def test_install_is_a_no_op_when_the_label_cannot_be_read
    runner = ->(args) { command_of(args) == 'display-message' ? nil : flunk('no other command expected') }
    subject = title(runner: runner)

    subject.install('developer')

    assert_empty @stream.string
  end

  def test_runner_failures_never_raise
    subject = title(runner: ->(_args) { raise Errno::ENOENT, 'tmux' })

    subject.install('developer')
    subject.restore

    assert_empty @stream.string
  end

  def test_commands_omit_the_target_without_a_pane
    title(env: { 'TMUX' => 'x' }, runner: recording_runner).install('developer')

    assert_includes @calls, %w[rename-window developer]
  end
end
