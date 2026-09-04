# frozen_string_literal: true

module Letsdo
  module Tui
    # The TUI controller: owns the terminal lifecycle, the background input
    # thread and the repaint loop around an orchestrator run.
    #
    # Threading model (the orchestrator loop stays on the calling thread,
    # exactly as in plain mode — Letsdo::PiRunner's signal design keeps
    # working unchanged):
    #   main thread    — the injected block (Letsdo::AgentLoop#run with its
    #                    own signal traps): provider queries, agent runs,
    #                    streamer writes into the log, metrics events;
    #   input thread   — the SOLE repainter: polls keys (tty-reader),
    #                    drains the log snapshot, tracks the metrics
    #                    snapshot and repaints on keys, data, 1s timer
    #                    ticks and SIGWINCH. Never touches the loop.
    #
    # Interactive actions (footer lists them):
    #   ↑ / ↓ / PgUp / PgDn / Home / End — scroll; the view auto-follows
    #     the newest line while at the bottom (tail -f semantics);
    #   p — pause/resume with REAL suspension (TASK-67): while a run is
    #     active the pi group is frozen with SIGSTOP (runner.pause) and
    #     the display freezes (PAUSED in the header, the log keeps
    #     buffering, the view stays); between runs the shared
    #     Control::PauseGate is toggled so the loop starts no new run.
    #     Keys still repaint; the footer hint flips between 'p pause'
    #     and 'p resume';
    #   r — immediate backlog re-query for the 'left' metric;
    #   q / Ctrl-C — quit: exactly the signal-stop unwinding — Letsdo::Stopped
    #     raised into the main thread terminates the pi child (PiRunner
    #     rescue, CONT-before-TERM so a paused run is still killable), stops
    #     the loop (AgentLoop rescue) and restores the terminal from the
    #     ensure block; exit code 0.
    #
    # Signals: SIGWINCH sets a flag → the input thread re-queries the size
    # and repaints (no corruption). SIGINT/SIGTERM keep working through the
    # loop's own traps (main thread).
    class Session
      # 1s session-timer repaint interval.
      REPAINT_INTERVAL = 1.0
      # Poll sleep when the display is frozen or nothing happened (avoids a
      # busy loop while still repainting at the timer interval).
      IDLE_SLEEP = 0.01
      # How long teardown waits for the input thread to finish its poll.
      INPUT_JOIN_TIMEOUT = 2.0

      # @param name [String] agent name (header identity)
      # @param handle [String] assignee handle (header identity)
      # @param log [LogBuffer] the combined log the streamer writes into
      # @param metrics [Metrics] the header metrics facade
      # @param terminal [Terminal] the terminal wrapper
      # @param input [Input] the key reader
      # @param refresh [Proc, nil] callable → open task count (Integer) or
      #        nil (backlog unreadable); 'r' uses it for an immediate
      #        re-query
      # @param wait_seconds [Numeric] retry interval for the waiting state
      # @param clock [Proc] monotonic clock for tick timing (injectable)
      # @param pause_gate [Letsdo::Control::PauseGate, nil] the shared
      #        between-runs pause flag: 'p' toggles it; nil (unit contexts)
      #        keeps 'p' display-freeze-only
      # @param runner [Proc, nil] callable → the current agent runner
      #        (Letsdo::PiRunner); 'p' suspends/resumes it (SIGSTOP/SIGCONT)
      #        when a run is active, a no-op otherwise
      def initialize(name:, handle:, log:, metrics:, terminal:, input:,
                     refresh: nil, wait_seconds: 10.0, clock: nil,
                     pause_gate: nil, runner: nil)
        @name = name
        @handle = handle
        @log = log
        @metrics = metrics
        @terminal = terminal
        @input = input
        @refresh = refresh
        @wait_seconds = wait_seconds
        @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        @pause_gate = pause_gate
        @runner = runner
        @offset = 0
        @follow = true
        @paused = false
        @stop = false
        @winch = false
        @body_height = 1
        @seen_version = 0
        @input_thread = nil
      end

      # Runs the TUI around the given orchestrator work.
      #
      # The block runs on the calling thread. On quit (q/Ctrl-C) or a stop
      # signal Letsdo::Stopped unwinds it; the terminal is restored from
      # the ensure block on every exit path.
      #
      # @yield the orchestrator run (e.g. Letsdo::AgentLoop#run)
      # @return [Integer] the block's result, or 0 when stopped
      def run(&work)
        install_winch_handler
        @terminal.enter
        start_input_thread
        result = work.call
        result
      rescue Letsdo::Stopped
        0
      ensure
        stop_input_thread
        leave_terminal
        restore_winch_handler
      end

      private

      # The input thread body: the only place that writes to the terminal.
      def input_loop
        with_raw_input do
          repaint
          @last_repaint = @clock.call
          loop do
            break if @stop

            key = @input.next_key
            handled = key ? handle_key(key) : false
            winch = take_winch
            handled = true if winch
            now = @clock.call
            tick = now - @last_repaint >= REPAINT_INTERVAL
            new_data = @log.version != @seen_version
            if handled || (!@paused && (tick || new_data))
              repaint
              @last_repaint = @clock.call
            else
              sleep(IDLE_SLEEP)
            end
          end
        end
      rescue StandardError
        # The input thread must never die loudly into the middle of the
        # screen, and a quiet exit still leaves the loop running (teardown
        # joins it). Terminal state is restored by the ensure blocks.
        nil
      end

      def handle_key(key)
        case key
        when :up, :page_up
          @offset -= key == :page_up ? page_step : 1
          @follow = false
          true
        when :down, :page_down
          @offset += key == :page_down ? page_step : 1
          true # repaint decides re-sticking at the bottom
        when :home
          @offset = 0
          @follow = false
          true
        when :end
          @follow = true
          true
        when :p
          toggle_pause
          true
        when :r
          refresh
          true
        when :q, :ctrl_c
          quit
          false # leaving the session; no repaint needed
        else
          false
        end
      end

      # Immediate backlog re-query: the provider is re-run on this thread
      # (a subprocess call, thread-safe) and the count reaches the header
      # snapshot.
      def refresh
        return unless @refresh

        @metrics.provider_result(@refresh.call)
      end

      # Pause/resume with real suspension (TASK-67): mid-run (metrics
      # current_task distinguishes the running state) the pi group is
      # frozen with SIGSTOP via the agent runner; between runs the shared
      # PauseGate blocks the loop from starting the next task. The gate is
      # set FIRST so no new run can sneak in between the flag and the
      # runner pause; the runner call is a no-op when no run is active
      # (nil runner or a finished one re-pausing nothing). The display
      # freezes in both cases (PAUSED badge), the log keeps buffering.
      def toggle_pause
        @paused = !@paused
        if @paused
          @pause_gate&.pause
          @runner&.call&.pause
        else
          @pause_gate&.resume
          @runner&.call&.resume
        end
      end

      # Quit = the same unwinding as a stop signal: Letsdo::Stopped raised
      # into the main thread (inside the orchestrator work) terminates the
      # pi child and stops the loop; the ensure block restores the
      # terminal. No-op after teardown already started. The stop flag is
      # set BEFORE the raise so the input thread breaks its loop right away
      # and renders no frames during the unwind (TASK-67 CONTROL MODEL).
      def quit
        return if @stop

        @stop = true
        Thread.main.raise(Letsdo::Stopped)
      end

      # Repaints the whole frame from the current state.
      def repaint
        lines, version = @log.lines
        @seen_version = version
        height, width = @terminal.size
        @body_height = Renderer.body_height_for(height)
        max_offset = Renderer.max_offset(lines, @body_height)
        if @paused
          @offset = [[@offset, max_offset].min, 0].max
        elsif @follow
          @offset = max_offset
        else
          @offset = [[@offset, max_offset].min, 0].max
          @follow = true if @offset == max_offset
        end
        frame = Renderer.render(
          metrics: @metrics.snapshot, lines: lines, width: width, height: height,
          offset: @offset, follow: @follow, paused: @paused,
          wait_seconds: @wait_seconds
        )
        @terminal.render(frame)
      end

      # Page height for PgUp/PgDn.
      def page_step
        @body_height.positive? ? @body_height : 1
      end

      def take_winch
        flag = @winch
        @winch = false
        flag
      end

      # Raw keyboard mode for the whole input session (the tty-reader
      # per-read raw wraps would leave the terminal echoing between polls);
      # no-op for non-tty inputs (tests use a pipe).
      def with_raw_input(&block)
        if @input.stdin.tty? && @input.stdin.respond_to?(:raw)
          @input.stdin.raw(&block)
        else
          block.call
        end
      end

      def install_winch_handler
        Signal.trap("SIGWINCH") { @winch = true }
      rescue ArgumentError
        nil # no SIGWINCH on this platform — no resize repaints
      end

      def restore_winch_handler
        Signal.trap("SIGWINCH", "DEFAULT")
      rescue ArgumentError
        nil
      end

      def start_input_thread
        @input_thread = Thread.new { input_loop }
        @input_thread.report_on_exception = false
        @input_thread
      end

      def stop_input_thread
        @stop = true
        thread = @input_thread
        return unless thread

        thread.join(INPUT_JOIN_TIMEOUT) || thread.kill
      end

      def leave_terminal
        @terminal.leave
      end
    end
  end
end