# frozen_string_literal: true

module Letsdo
  module Tui
    # The frame renderer: a pure function from state to text.
    #
    #   (metrics snapshot, log lines, terminal width/height,
    #    view offset / follow / paused) → a framed String
    #
    # Pure means: no IO, no terminal, no clock — the same inputs always
    # produce the same string, so every rendering path (session controller,
    # tests) feeds it identically and tests need no real TTY.
    #
    # Layout (bottom line is the last, no trailing newline):
    #
    #   letsdo · developer (@developer)            session 00:12:34
    #   done 3 · left 2 · task TASK-42 · 00:03:21
    #   ├────────────────────────────────────────────────────────────┤
    #   <body_height scrollable log lines, newest at the bottom>
    #   ↑/↓ PgUp/PgDn scroll · p pause · r refresh · q quit
    module Renderer
      HEADER_HEIGHT = 2
      FOOTER_HEIGHT = 1
      DIVIDER_HEIGHT = 1
      ELLIPSIS = "…"

      # Renders the full frame.
      #
      # @param metrics [Metrics::Snapshot] header metrics snapshot
      # @param lines [Array<String>] log lines, oldest first
      # @param width [Integer] terminal width in columns
      # @param height [Integer] terminal height in rows (>= HEADER_HEIGHT +
      #        FOOTER_HEIGHT + DIVIDER_HEIGHT + 1)
      # @param offset [Integer] index of the first visible log line
      # @param follow [Boolean] whether the view sticks to the newest line
      # @param paused [Boolean] display-freeze state (PAUSED in the header)
      # @param wait_seconds [Numeric] retry interval shown in the waiting
      #        state
      # @return [String] the framed screen, lines joined with "\n"
      def self.render(metrics:, lines:, width:, height:, offset:, follow:, paused:, wait_seconds: 10.0)
        body_height = body_height_for(height)
        frame = []
        frame << header_line(metrics, width)
        frame << state_line(metrics, width, paused, wait_seconds)
        frame << divider_line(width)
        body_lines(lines, offset, body_height, width).each { |line| frame << line }
        frame << footer_line(width)
        frame.join("\n")
      end

      # The number of body lines a terminal of the given height fits.
      def self.body_height_for(height)
        [height - HEADER_HEIGHT - FOOTER_HEIGHT - DIVIDER_HEIGHT, 1].max
      end

      # The index of the last line that can be the first visible one.
      def self.max_offset(lines, body_height)
        [lines.length - body_height, 0].max
      end

      # Clamps a view offset into the valid range.
      def self.clamp_offset(offset, lines, body_height)
        [[offset, max_offset(lines, body_height)].min, 0].max
      end

      def self.header_line(metrics, width)
        title = "letsdo · #{metrics.name} (#{metrics.handle})"
        timer = "session #{format_duration(metrics.session_seconds)}"
        fit_line_with_right(title, timer, width)
      end

      # The state line: done/left plus either the running task with its
      # elapsed time, a waiting reason, or the PAUSED overlay.
      def self.state_line(metrics, width, paused, wait_seconds)
        parts = ["done #{metrics.done}", "left #{metrics.left.nil? ? "?" : metrics.left}"]
        if paused
          parts << "PAUSED"
        elsif metrics.current_task
          parts << "task #{metrics.current_task}"
          parts << format_duration(metrics.current_task_seconds) if metrics.current_task_seconds
        else
          parts << "waiting: #{waiting_reason(metrics.left, wait_seconds)}"
        end
        fit_line(parts.join(" · "), width)
      end

      def self.body_lines(lines, offset, body_height, width)
        Array.new(body_height) do |index|
          line = lines[offset + index]
          line.nil? ? (" " * width) : fit_line(line, width)
        end
      end

      def self.divider_line(width)
        return "" if width < 4

        body = "─" * (width - 2)
        "├#{body}┤"
      end

      def self.footer_line(width)
        fit_line("↑/↓ PgUp/PgDn scroll · p pause · r refresh · q quit", width)
      end

      # "no open tasks, retrying in 10s" style reason for the waiting state.
      def self.waiting_reason(left, wait_seconds)
        formatted = wait_seconds == wait_seconds.to_i ? wait_seconds.to_i : wait_seconds
        suffix = " (retry in #{formatted}s)"
        if left.nil?
          "backlog unavailable#{suffix}"
        elsif left.zero?
          "no open tasks#{suffix}"
        else
          "next task"
        end
      end

      # HH:MM:SS (hours can exceed two digits for long sessions).
      def self.format_duration(seconds)
        total = [seconds.to_i, 0].max
        hours, remainder = total.divmod(3600)
        minutes, secs = remainder.divmod(60)
        format("%02d:%02d:%02d", hours, minutes, secs)
      end

      def self.fit_line_with_right(left, right, width)
        gap = [width - display_width(left) - display_width(right), 0].max
        fit_line("#{left}#{" " * gap}#{right}", width)
      end

      # Fits a line to the width: display-width truncation with an
      # ellipsis, then whitespace padding so the whole line is rewritten
      # (a narrow terminal resize leaves no stale content).
      def self.fit_line(line, width)
        fitted = fit(line, width)
        pad = width - display_width(fitted)
        pad.positive? ? fitted + (" " * pad) : fitted
      end

      # Cuts the line on a character boundary by display width, adding an
      # ellipsis when anything was cut. Lines within the width are kept
      # verbatim.
      def self.fit(line, width)
        text_width = display_width(line)
        return line if width >= text_width
        return "" if width <= 1

        out = +""
        acc = 0
        limit = width - display_width(ELLIPSIS)
        line.each_char do |char|
          char_width = display_width(char)
          break if acc + char_width > limit

          out << char
          acc += char_width
        end
        out << ELLIPSIS
        out
      end

      # Display width of a string (Unicode-aware: ✓/⚙/…/CJK are counted
      # correctly). Requires "unicode/display_width" lazily so the plain
      # (non-TTY) path needs no extra gems.
      def self.display_width(text)
        return 0 if text.nil? || text.empty?

        require "unicode/display_width"
        Unicode::DisplayWidth.of(text)
      end
    end
  end
end