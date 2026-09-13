# frozen_string_literal: true

module Letsdo
  module Tui
    # Terminal lifecycle for the TUI session: entering/leaving the alternate
    # screen, the tmux window label around it, and the SIGWINCH handler.
    # Extracted from Session so the class stays within the class-length limit
    # (same reason as SessionKeys / SessionView).
    module SessionTerminal
      private

      # Prepares the session terminal: SIGWINCH tracking, the alternate
      # screen, and — inside tmux — the agent-named window label.
      def install_terminal
        install_winch_handler
        @terminal.enter
        @title&.install(@name)
      end

      # Runs the full terminal cleanup on every exit path: stops the input
      # thread, restores the tmux window label, leaves the alternate screen
      # and restores the SIGWINCH handler.
      def restore_terminal
        stop_input_thread
        @title&.restore
        leave_terminal
        restore_winch_handler
      end

      def leave_terminal
        @terminal.leave
      end

      def install_winch_handler
        Signal.trap('SIGWINCH') { @winch = true }
      rescue ArgumentError
        nil
      end

      def restore_winch_handler
        Signal.trap('SIGWINCH', 'DEFAULT')
      rescue ArgumentError
        nil
      end
    end
  end
end
