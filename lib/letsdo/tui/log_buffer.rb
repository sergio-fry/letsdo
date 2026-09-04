# frozen_string_literal: true

module Letsdo
  module Tui
    # The combined, thread-safe log behind the TUI stream.
    #
    # The TUI uses one buffer for everything the agent produces: answer
    # text deltas, tool lines, loop service messages — in arrival order,
    # exactly what Letsdo::OutputStreamer emits. The streamer (main thread)
    # appends via #write/#puts; the TUI input thread reads a snapshot via
    # #lines for rendering. Both operations are mutex-protected.
    #
    # Lines are capped (oldest dropped); a partial last line (the agent's
    # in-progress text) is kept separately so rendering can show the live
    # tail. #divider appends a run-boundary separator. A monotonically
    # increasing version lets the renderer skip repaints when nothing new
    # arrived.
    class LogBuffer
      # Default maximum number of complete lines kept in the buffer.
      MAX_LINES = 2_000
      # The run-boundary separator line.
      DIVIDER = "─" * 40

      # @param max_lines [Integer] maximum number of complete lines kept;
      #        older lines are dropped
      def initialize(max_lines: MAX_LINES)
        @mutex = Mutex.new
        @lines = []
        @pending = +""
        @max_lines = max_lines
        @version = 0
      end

      # Appends raw text (IO-compatible, used by Letsdo::OutputStreamer).
      #
      # @param text [String] the next chunk of the stream
      def write(text)
        return if text.nil? || text.empty?

        @mutex.synchronize { append(text) }
        self
      end

      # Appends a complete line with a trailing newline (IO-compatible,
      # used by Letsdo::AgentLoop service messages).
      #
      # @param text [String, nil] the line or nil for an empty line
      def puts(text = nil)
        write(text.nil? ? "\n" : "#{text}\n")
        self
      end

      # IO-compatible no-op: an in-memory buffer never needs flushing.
      def flush
        self
      end

      # Appends a run-boundary divider line (skipped when the buffer is
      # still empty — there is no boundary yet).
      def divider
        @mutex.synchronize do
          @lines << DIVIDER unless @lines.empty? && @pending.empty?
          @version += 1
        end
        self
      end

      # The current buffer content for rendering: complete lines plus the
      # pending partial line, and the current version.
      #
      # @return [Array(Array<String>, Integer)] lines and version
      def lines
        @mutex.synchronize do
          snapshot = @lines.dup
          snapshot << @pending.dup unless @pending.empty?
          [snapshot, @version]
        end
      end

      # Monotonic change counter. The input thread compares this to the
      # last rendered version so it can skip repaints when the log is idle.
      #
      # @return [Integer]
      def version
        @mutex.synchronize { @version }
      end

      private

      # Splits the raw chunk on newlines: everything before the last
      # newline becomes complete lines, the trailing fragment stays
      # pending. The pending fragment is moved to the completed list as
      # soon as a newline arrives, so line order is preserved.
      def append(text)
        chunks = text.split("\n", -1)
        @pending << chunks.shift
        chunks.each do |chunk|
          @lines << @pending
          @pending = chunk
        end
        trim_lines
        @version += 1
      end

      def trim_lines
        excess = @lines.length - @max_lines
        @lines.shift(excess) if excess.positive?
      end
    end
  end
end