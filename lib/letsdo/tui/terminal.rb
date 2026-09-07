# frozen_string_literal: true

module Letsdo
  module Tui
    # Thin wrapper over the terminal: alternate screen, cursor handling and
    # frame rendering, all through an injected stream (StringIO in tests).
    #
    # The alternate screen is entered/exited with the raw ANSI sequences
    # (tty-cursor has no alt-screen helper); cursor hide/show and the home
    # position come from TTY::Cursor. The frame render is a single write:
    # cursor-to-top + the framed text. Resizes are handled by re-querying
    # the size provider before each render.
    class Terminal
      # Alternate screen buffer on (keeps the caller's terminal content).
      ENTER_ALT_SCREEN = "\e[?1049h"
      # Alternate screen buffer off.
      LEAVE_ALT_SCREEN = "\e[?1049l"
      # Cursor-to-home-column-1-row-1 (cell 1,1 per tty-cursor convention).
      HOME = "\e[1;1H"

      # @param stream [IO] the terminal output stream
      # @param size_provider [Proc] callable → [height, width]; defaults to
      #        TTY::Screen.size; injected in tests for deterministic size
      def initialize(stream:, size_provider: nil)
        require 'tty-screen' unless defined?(TTY::Screen)

        @stream = stream
        @size_provider = size_provider ||
                         lambda {
                           size = TTY::Screen.size
                           [size[0] || 24, size[1] || 80]
                         }
      end

      # Enters the alternate screen and hides the cursor.
      def enter
        write(ENTER_ALT_SCREEN + cursor.hide)
      end

      # Shows the cursor and leaves the alternate screen.
      def leave
        write(cursor.show + LEAVE_ALT_SCREEN)
      end

      # Repaints the whole frame: cursor to the top left, then the frame.
      #
      # Row separators are written as CRLF (\r\n), never bare LF. The TUI
      # input thread holds stdin in io-console raw mode for the whole
      # session, and raw mode clears OPOST on the shared tty — without it a
      # bare \n no longer implies a carriage return, so every row after the
      # first would start at the previous row's end column and the frame
      # would wrap/scroll into the "blank activity pane" scramble (TASK-82).
      # Explicit CRLF renders correctly both in raw mode and on terminals
      # whose ONLCR already expands \n (a doubled CR is harmless).
      #
      # @param frame [String] the rendered screen (see Letsdo::Tui::Renderer)
      def render(frame)
        write(HOME + frame.gsub("\n", "\r\n"))
      end

      # The current terminal size.
      #
      # @return [Array(Integer, Integer)] height and width in rows/columns
      def size
        dims = @size_provider.call
        [dims[0] || 24, dims[1] || 80]
      end

      private

      # Loaded lazily (like tty-screen/tty-reader) so requiring letsdo on a
      # clean Ruby loads no tty-* gems — only the interactive TTY path needs
      # them (TASK-78).
      def cursor
        require 'tty-cursor' unless defined?(TTY::Cursor)
        TTY::Cursor
      end

      def write(text)
        @stream.write(text)
        @stream.flush
      end
    end
  end
end
