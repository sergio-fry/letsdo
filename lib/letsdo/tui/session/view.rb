# frozen_string_literal: true

module Letsdo
  module Tui
    # Frame painting and view-offset tracking for the TUI session.
    module SessionView
      private

      def input_loop
        repaint
        @last_repaint = @clock.call
        loop { break if @stop || !poll_once }
      rescue Letsdo::Stopped
        raise
      rescue StandardError => e
        # A paint/input/resize failure here must not leave a blank,
        # unresponsive TUI: record it and interrupt the run so it is surfaced
        # after the terminal is restored (TASK-92).
        return if @stop

        @input_error = e
        quit
      end

      def poll_once
        handled = process_input
        if handled || (!@paused && (tick? || new_data?))
          repaint
          @last_repaint = @clock.call
        else
          sleep(Session::IDLE_SLEEP)
        end
        true
      end

      def process_input
        key = @input.next_key
        handled = key ? handle_key(key) : false
        take_winch ? true : handled
      end

      def tick?
        @clock.call - @last_repaint >= Session::REPAINT_INTERVAL
      end

      def new_data?
        @log.version != @seen_version
      end

      def take_winch
        flag = @winch
        @winch = false
        flag
      end

      def repaint
        lines, version = @log.lines
        @seen_version = version
        height, width = @terminal.size
        @body_height = Renderer.body_height_for(height)
        update_offset(lines)
        @terminal.render(frame_for(lines, width, height))
      end

      def update_offset(lines)
        max_offset = Renderer.max_offset(lines, @body_height)
        if @paused
          @offset = clamp_offset(max_offset)
        elsif @follow
          @offset = max_offset
        else
          @offset = clamp_offset(max_offset)
          @follow = true if @offset == max_offset
        end
      end

      def clamp_offset(max_offset)
        [[@offset, max_offset].min, 0].max
      end

      def frame_for(lines, width, height)
        Renderer.render(
          metrics: @metrics.snapshot, lines: lines,
          size: { width: width, height: height },
          view: { offset: @offset, paused: @paused },
          wait_seconds: @wait_seconds
        )
      end

      def page_step
        @body_height.positive? ? @body_height : 1
      end
    end
  end
end
