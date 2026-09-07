# frozen_string_literal: true

module Letsdo
  # Captures a child command's stdout and stderr (like Open3.capture3)
  # while tolerating an asynchronous Letsdo::Stopped that lands mid-call —
  # a TUI quit or a signal raised into the main thread. Open3's capture3
  # is not interruption-safe: its ensure closes the pipes while its reader
  # threads are still blocked in IO#read, and each reader then dies with
  # "stream closed in another thread" and prints a report_on_exception dump.
  #
  # Here the reader threads report no exception and rescue that benign
  # IOError, and the child is reaped even when the wait is interrupted, so
  # a stop can never leave dumps or zombies. Other reader errors still
  # re-raise through Thread#value, keeping real failures visible.
  class Capture
    # @param args [Array] command arguments for Process.spawn (an optional
    #        leading environment hash is preserved)
    # @param chdir [String, nil] working directory for the child (nil =
    #        inherit the current one)
    def initialize(*args, chdir: nil)
      @args = args
      @chdir = chdir
      @out_r, @out_w = IO.pipe
      @err_r, @err_w = IO.pipe
    end

    # Runs the command.
    #
    # @return [Array(String, String, Process::Status)] stdout, stderr, status
    def run
      @pid = spawn_child
      @out_w.close
      @err_w.close
      readers = [quiet_reader(@out_r), quiet_reader(@err_r)]
      status = wait_and_reap(@pid)
      @reaped = true
      [readers[0].value, readers[1].value, status]
    ensure
      cleanup
    end

    private

    def spawn_child
      opts = { out: @out_w, err: @err_w, pgroup: true }
      opts[:chdir] = @chdir if @chdir
      Process.spawn(*@args, **opts)
    end

    # A stdout/stderr reader thread that stays silent when its pipe is
    # closed while still reading (the stop path) and returns nil instead.
    def quiet_reader(pipe)
      Thread.new do
        Thread.current.report_on_exception = false
        pipe.read
      rescue IOError
        nil
      end
    end

    def wait_and_reap(pid)
      _, status = Process.wait2(pid)
      status
    end

    # Kills the child's process group and reaps it when the normal wait was
    # interrupted (a stop raised into the main thread). Killing the whole
    # group also terminates any grandchildren that inherited the child's
    # stdout/stderr pipes, so none of them is left holding the pipes open
    # (TASK-84). A no-op when the child was already reaped normally.
    def terminate_and_reap(pid)
      return unless pid

      kill_group(pid)
      reap(pid)
    end

    def kill_group(pid)
      Process.kill('TERM', -pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    def reap(pid)
      Process.wait2(pid)
    rescue Errno::ECHILD
      nil
    end

    def cleanup
      close_quietly(@out_w)
      close_quietly(@err_w)
      close_quietly(@out_r)
      close_quietly(@err_r)
      terminate_and_reap(@pid) unless @reaped
    end

    def close_quietly(io)
      io.close unless io.nil? || io.closed?
    rescue IOError
      nil
    end
  end
end
