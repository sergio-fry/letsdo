# frozen_string_literal: true

# The interactive TUI (TASK-42): a full-screen interface for letsdo <name>
# when stdout and stdin are terminals (TERM != "dumb"). In TUI mode the
# streamer and the loop driver feed a log buffer + metrics facade; the
# session renders a header (name + handle, done-in-session counter, session
# timer, tasks remaining, current-task elapsed, waiting/PAUSED states), a
# scrollable combined log and a key-help footer, and repaints from a
# background input thread. Non-TTY output stays the plain line-stream.
# Inside tmux the window is labeled with the agent name for the session and
# the previous label is restored on exit (TASK-90).
#
# Components:
#   Letsdo::Tui::LogBuffer  - thread-safe combined log (streamer target)
#   Letsdo::Tui::Metrics    - header metrics facade (loop driver events)
#   Letsdo::Tui::Renderer   - pure function: state → framed String
#   Letsdo::Tui::Terminal   - alt screen, cursor, frame rendering
#   Letsdo::Tui::Input      - tty-reader key decoding (injectable)
#   Letsdo::Tui::WindowTitle - names the tmux window after the agent
#   Letsdo::Tui::Session    - controller: terminal lifecycle + input thread

require_relative 'tui/log_buffer'
require_relative 'tui/metrics'
require_relative 'tui/renderer'
require_relative 'tui/terminal'
require_relative 'tui/window_title'
require_relative 'tui/input'
require_relative 'tui/session'
