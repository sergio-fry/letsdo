# frozen_string_literal: true

require_relative '../config'

module Letsdo
  module Backends
    # The documented backend protocol plus shared process-lifecycle helpers.
    #
    # Concrete adapters (Pi) add subprocess management and streaming.
    # In-process fakes (test helpers) override terminate_now and skip
    # spawning entirely.
    #
    # Protocol:
    #   run                              → Integer child exit code
    #   terminate_now                    trap-safe, no waits/IO
    #   terminate(signal:, grace:, tick:) → no-op when already finished
    #   pause / resume                   SIGSTOP/SIGCONT to the process group
    #   debug(message)                   '[letsdo] pi:' when debug is on
    #
    # Normalized events emitted at the injected streamer:
    #   text_delta(delta)        tool_start(name, args: nil)
    #   tool_result(name, text)  finish
    # finish is called exactly once per run.
    class Backend
      # @param prompt [String] the stripped prompt text (no front-matter).
      # @param streamer [Letsdo::OutputStreamer] normalized event sink.
      # @param debug  [Boolean, nil] trace override; nil → check env.
      # @param config [Letsdo::Config, nil] debug source (LETSDO_DEBUG);
      #        nil → Config.new for env-only lookups.
      def initialize(prompt:, streamer:, debug: nil, config: nil)
        @prompt   = prompt
        @streamer = streamer
        @debug    = debug.nil? ? (config || Config.new).debug? : debug
        @pid = nil
        @reaped_status = nil
      end

      # Run the backend.  Subclasses must override; the base returns nil.
      def run
        raise NotImplementedError,
              "#{self.class.name} must implement #run"
      end

      # ── signal helpers ────────────────────────────────────────────
      # All are trap-safe (no waits, no IO) and swallow ESRCH/EPERM.

      def terminate_now
        pid = @pid
        send_signal('TERM', pid) if pid
      end

      def pause
        pid = @pid
        send_signal('CONT', pid) if pid
        send_signal('SIGSTOP', pid) if pid
      end

      def resume
        pid = @pid
        send_signal('SIGCONT', pid) if pid
      end

      # Graceful stop, then SIGKILL after *grace* seconds.
      # Returns true when the process already finished.
      def terminate(signal: 'TERM', grace: 3.0, tick: 0.05)
        pid = @pid
        return true unless pid

        send_signal('CONT', pid)
        send_signal(signal, pid)
        wait_for_exit(pid, grace, tick)
      end

      # ── tracing ───────────────────────────────────────────────────

      def debug(message)
        warn("[letsdo] pi: #{message}") if @debug
      end

      private

      # ── process-lifecycle helpers (shared with concrete adapters) ──

      def wait_status(pid, nonblock: false)
        _, status = Process.wait2(pid, nonblock ? Process::WNOHANG : 0)
        @reaped_status = status if status
        status
      rescue Errno::ECHILD
        @reaped_status
      end

      def wait_for_exit(pid, grace, tick)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + grace
        loop do
          status = wait_status(pid, nonblock: true)
          return status if status
          break unless alive?(pid)
          return kill_and_reap(pid, tick) if overdue_deadline?(deadline)

          sleep(tick)
        end
        true
      end

      def overdue_deadline?(deadline)
        Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      end

      def kill_and_reap(pid, tick)
        send_signal('KILL', pid)
        sleep(tick)
        wait_status(pid, nonblock: true) || true
      end

      def send_signal(signal, pid)
        Process.kill(signal, -pid)
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end

      def alive?(pid)
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        false
      end

      # 0/N from a clean exit; 128+signal for a killed run; 1 when unknown.
      def exit_code(status)
        return 1 if status.nil?
        return status.exitstatus if status.exitstatus

        status.termsig ? 128 + status.termsig : 1
      end
    end
  end
end
