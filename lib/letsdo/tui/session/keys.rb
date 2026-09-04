# frozen_string_literal: true

module Letsdo
  module Tui
    # Keyboard actions for the TUI session input thread.
    module SessionKeys
      private

      KEY_METHODS = {
        up: :scroll_up,
        page_up: :scroll_page_up,
        down: :scroll_down,
        page_down: :scroll_page_down,
        home: :go_home,
        end: :go_end,
        p: :pause_key,
        r: :refresh_key,
        q: :quit_key,
        ctrl_c: :quit_key
      }.freeze

      def handle_key(key)
        send(KEY_METHODS.fetch(key, :ignore_key))
      end

      def scroll_up
        @offset -= 1
        @follow = false
        true
      end

      def scroll_page_up
        @offset -= page_step
        @follow = false
        true
      end

      def scroll_down
        @offset += 1
        true
      end

      def scroll_page_down
        @offset += page_step
        true
      end

      def go_home
        @offset = 0
        @follow = false
        true
      end

      def go_end
        @follow = true
        true
      end

      def pause_key
        toggle_pause
        true
      end

      def refresh_key
        refresh
        true
      end

      def quit_key
        quit
        false
      end

      def ignore_key
        false
      end

      def refresh
        return unless @refresh

        @metrics.provider_result(@refresh.call)
      end

      def toggle_pause
        @paused = !@paused
        send(@paused ? :engage_pause : :engage_resume)
      end

      def engage_pause
        invoke_gate(:pause)
        invoke_runner(:pause)
      end

      def engage_resume
        invoke_gate(:resume)
        invoke_runner(:resume)
      end

      def invoke_gate(action)
        gate = @pause_gate
        return unless gate

        gate.public_send(action)
      end

      def invoke_runner(action)
        runner = @runner.call if @runner
        return unless runner

        runner.public_send(action)
      end

      def quit
        return if @stop

        @stop = true
        Thread.main.raise(Letsdo::Stopped)
      end
    end
  end
end
