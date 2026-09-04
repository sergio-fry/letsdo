# frozen_string_literal: true

module Letsdo
  # Process-group control for a running pi child.
  module PiRunnerProcess
    def terminate(signal: 'TERM', grace: 3.0, tick: 0.05)
      pid = @pid
      return true unless pid

      send_signal('CONT', pid)
      send_signal(signal, pid)
      wait_for_exit(pid, grace, tick)
    end

    private

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

    def wait_status(pid, nonblock: false)
      _, status = Process.wait2(pid, nonblock ? Process::WNOHANG : 0)
      @reaped_status = status if status
      status
    rescue Errno::ECHILD
      @reaped_status
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

    def exit_code(status)
      return 1 if status.nil?
      return status.exitstatus if status.exitstatus

      status.termsig ? 128 + status.termsig : 1
    end
  end
end
