# frozen_string_literal: true

require 'open3'

module Letsdo
  module Tui
    # Names the tmux window after the running agent (TASK-90) and restores
    # the previous label on exit.
    #
    # tmux labels a window after its foreground process (automatic-rename),
    # which for letsdo is always "ruby" — useless when one agent runs per
    # pane. Two tmux facts (verified against tmux 3.4) shape this class:
    #
    #   * an OSC-2 title escape only sets the *pane* title; the window label
    #     still follows the process name;
    #   * so the window must be renamed explicitly and automatic-rename
    #     disabled for the session, or tmux overwrites the label.
    #
    # Every tmux call goes through an injectable runner (tests stub it) and
    # every failure is swallowed: title handling may never break a session.
    # Being inside tmux on a TTY stream is the gate, so outside tmux nothing
    # is written and the tmux binary is never invoked.
    class WindowTitle
      # OSC-2 title escape; only emitted inside tmux (see #install).
      TITLE_TEMPLATE = "\e]2;%s\a"
      # automatic-rename value meaning "no explicit setting" (tmux default on).
      UNSET = ''

      # @param stream [IO] terminal output stream (title escapes go here)
      # @param env [Hash, ENV] source of TMUX / TMUX_PANE
      # @param runner [Proc, nil] callable(Array<String>) → stdout String;
      #        defaults to the real tmux binary, stubbed in tests
      def initialize(stream:, env:, runner: nil)
        @stream = stream
        @env = env
        @runner = runner || method(:run_tmux)
        @previous = nil
      end

      # Saves the current window label and labels the window with `name`.
      # No-op outside tmux, or when the stream is not a TTY.
      def install(name)
        return unless tmux?

        state = capture
        return unless state

        label(name)
        write_title(name)
        @previous = state
      end

      # Puts the saved label back and restores automatic-rename, unsetting
      # the option when it had no explicit value before (no leftover state).
      def restore
        state = @previous
        return unless state

        @previous = nil
        label(state[:name])
        restore_automatic_rename(state[:automatic_rename])
        write_title(state[:name])
      end

      # Whether a tmux session hosts this process and titles can be set.
      def tmux?
        return false unless @stream.respond_to?(:tty?) && @stream.tty?

        !@env['TMUX'].to_s.empty?
      end

      private

      # Renames the window, then disables automatic-rename so tmux keeps the
      # label for the whole session.
      def label(name)
        tmux('rename-window', name)
        tmux('set-option', '-w', 'automatic-rename', 'off')
      end

      def restore_automatic_rename(value)
        return tmux('set-option', '-w', '-u', 'automatic-rename') if value == UNSET

        tmux('set-option', '-w', 'automatic-rename', value)
      end

      # The current window label and automatic-rename value, or nil when the
      # label cannot be read (no tmux, no server, failed command).
      def capture
        name = tmux('display-message', '-p', "\#{window_name}").to_s.strip
        return nil if name.empty?

        { name: name, automatic_rename: automatic_rename_option }
      end

      def automatic_rename_option
        tmux('show-window-options', '-v', 'automatic-rename').to_s.strip
      end

      def write_title(text)
        @stream.write(format(TITLE_TEMPLATE, text))
        @stream.flush
      end

      # One tmux command through the injected runner; a missing binary, an
      # unreachable server or a failed command all yield nil.
      def tmux(*args)
        @runner.call(window_args(*args))
      rescue StandardError
        nil
      end

      # Targets the pane letsdo runs in, so the commands act on the right
      # window even when the tmux server has no attached client. `-t` is a
      # command option and must follow the subcommand.
      def window_args(*args)
        pane = @env['TMUX_PANE'].to_s
        return args if pane.empty?

        [args.first, '-t', pane, *args.drop(1)]
      end

      # @param args [Array<String>] tmux arguments
      # @return [String] the command's stdout
      def run_tmux(args)
        out, _err, status = Open3.capture3('tmux', *args)
        raise "tmux failed: #{args.join(' ')}" unless status.success?

        out
      end
    end
  end
end
