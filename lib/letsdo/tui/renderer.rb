# frozen_string_literal: true

module Letsdo
  module Tui
    # The frame renderer: a pure function from state to text.
    #
    #   (metrics snapshot, log lines, terminal size, view,
    #    wait interval) → a framed String
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
    #   ↑/↓ PgUp/PgDn scroll · p pause/resume · r refresh · q quit
    module Renderer
      HEADER_HEIGHT = 2
      FOOTER_HEIGHT = 1
      DIVIDER_HEIGHT = 1
      ELLIPSIS = '…'

      # Renders the full frame.
      #
      # @param metrics [Metrics::Snapshot] header metrics snapshot
      # @param lines [Array<String>] log lines, oldest first
      # @param size [Hash{Symbol => Integer}] :width and :height of the
      #        terminal (rows >= HEADER_HEIGHT + FOOTER_HEIGHT +
      #        DIVIDER_HEIGHT + 1)
      # @param view [Hash{Symbol => Integer, Boolean}] :offset (index of
      #        the first visible log line) and :paused (display-freeze
      #        overlay)
      # @param wait_seconds [Numeric] retry interval shown in the waiting
      #        state
      # @return [String] the framed screen, lines joined with "\n"
      def self.render(metrics:, lines:, size:, view:, wait_seconds: 10.0)
        width = size.fetch(:width)
        paused = view.fetch(:paused)
        height = body_height_for(size.fetch(:height))
        [
          header_line(metrics, width),
          state_line(metrics, width, paused, wait_seconds),
          divider_line(width),
          *body_lines(lines, view.fetch(:offset), height, width),
          footer_line(width, paused)
        ].join("\n")
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
        title = "letsdo · #{metrics.name} (#{display_handle(metrics)})"
        timer = "session #{Text.format_duration(metrics.session_seconds)}"
        Text.fit_line_with_right(title, timer, width)
      end

      # The header keeps the historical "name (@assignee)" look: the '@'
      # is display notation only (TASK-96) — the tracker value is the bare
      # name, and a legacy @-prefixed handle is shown as stored.
      def self.display_handle(metrics)
        handle = metrics.handle.to_s
        handle.start_with?('@') ? handle : "@#{handle}"
      end

      # The state line: done/left plus either the running task with its
      # elapsed time, a waiting reason, or the PAUSED overlay.
      def self.state_line(metrics, width, paused, wait_seconds)
        parts = ["done #{metrics.done}", "left #{left_or_question(metrics.left)}"]
        parts.concat(state_overlay(metrics, paused, wait_seconds))
        Text.fit_line(parts.join(' · '), width)
      end

      def self.left_or_question(left)
        left.nil? ? '?' : left
      end

      # The current-state fragment after "left N ·": task + elapsed time,
      # a waiting reason, or the PAUSED overlay.
      def self.state_overlay(metrics, paused, wait_seconds)
        if paused
          ['PAUSED']
        elsif metrics.current_task
          overlay = ["task #{metrics.current_task}"]
          overlay << Text.format_duration(metrics.current_task_seconds) if metrics.current_task_seconds
          overlay
        else
          ["waiting: #{waiting_reason(metrics.left, wait_seconds)}"]
        end
      end

      def self.body_lines(lines, offset, body_height, width)
        Array.new(body_height) do |index|
          line = lines[offset + index]
          line.nil? ? (' ' * width) : Text.fit_line(line, width)
        end
      end

      def self.divider_line(width)
        return '' if width < 4

        body = '─' * (width - 2)
        "├#{body}┤"
      end

      # The key-help footer. The 'p' hint mirrors the toggle state:
      # 'p pause' when the run is active, 'p resume' when it is suspended
      # (the display is frozen, PAUSED in the header).
      def self.footer_line(width, paused)
        hint = paused ? 'p resume' : 'p pause'
        Text.fit_line("↑/↓ PgUp/PgDn scroll · #{hint} · r refresh · q quit", width)
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
          'next task'
        end
      end

      # Text fitting helpers — kept separate so the frame logic stays short.
      module Text
        # HH:MM:SS (hours can exceed two digits for long sessions).
        def self.format_duration(seconds)
          total = [seconds.to_i, 0].max
          hours, remainder = total.divmod(3600)
          minutes, secs = remainder.divmod(60)
          format('%<hours>02d:%<minutes>02d:%<secs>02d', hours: hours, minutes: minutes, secs: secs)
        end

        def self.fit_line_with_right(left, right, width)
          gap = [width - display_width(left) - display_width(right), 0].max
          fit_line("#{left}#{' ' * gap}#{right}", width)
        end

        # Fits a line to the width: display-width truncation with an
        # ellipsis, then whitespace padding so the whole line is rewritten
        # (a narrow terminal resize leaves no stale content).
        def self.fit_line(line, width)
          fitted = fit(line, width)
          pad = width - display_width(fitted)
          pad.positive? ? fitted + (' ' * pad) : fitted
        end

        # Cuts the line on a character boundary by display width, adding an
        # ellipsis when anything was cut. Lines within the width are kept
        # verbatim.
        def self.fit(line, width)
          text_width = display_width(line)
          return line if width >= text_width
          return '' if width <= 1

          "#{truncate(line, width - display_width(ELLIPSIS))}#{ELLIPSIS}"
        end

        # Characters of the line that fit into the width budget.
        def self.truncate(line, budget)
          out = +''
          acc = 0
          line.each_char do |char|
            char_width = display_width(char)
            break if acc + char_width > budget

            out << char
            acc += char_width
          end
          out
        end

        # Display width of a string (Unicode-aware: ✓/⚙/…/CJK are counted
        # correctly). Requires "unicode/display_width" lazily so the plain
        # (non-TTY) path needs no extra gems.
        def self.display_width(text)
          return 0 if text.nil? || text.empty?

          require 'unicode/display_width'
          Unicode::DisplayWidth.of(text)
        end
      end
    end
  end
end
