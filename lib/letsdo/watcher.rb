# frozen_string_literal: true

require 'fiddle/import'

module Letsdo
  # OS file-change watcher for the backlog folder.
  #
  # On Linux it subscribes to inotify (via Fiddle, no external gem) and wakes
  # as soon as a backlog entry changes; everywhere else it degrades to the
  # same periodic polling a plain sleeper would do. Either way the wait is
  # interruptible — a signal trap raising Letsdo::Stopped breaks the
  # underlying IO.select — and an internal self-pipe lets #wake interrupt a
  # blocked #wait from another thread.
  class Watcher
    # inotify event masks we subscribe to (Linux <sys/inotify.h>).
    IN_ACCESS       = 0x00000001
    IN_MODIFY       = 0x00000002
    IN_ATTRIB       = 0x00000004
    IN_CLOSE_WRITE  = 0x00000008
    IN_CLOSE_NOWRITE = 0x00000010
    IN_OPEN         = 0x00000020
    IN_MOVED_FROM   = 0x00000040
    IN_MOVED_TO     = 0x00000080
    IN_CREATE       = 0x00000100
    IN_DELETE       = 0x00000200
    IN_DELETE_SELF  = 0x00000400
    IN_MOVE_SELF    = 0x00000800

    RELEVANT_MASK = IN_CREATE | IN_MODIFY | IN_CLOSE_WRITE | IN_DELETE |
                    IN_MOVED_FROM | IN_MOVED_TO | IN_DELETE_SELF | IN_MOVE_SELF

    EXCLUDED_DIR = '.locks'

    # @param path [String] the watched folder (its direct entries)
    # @param poll_seconds [Float] fallback poll interval / select timeout
    def initialize(path:, poll_seconds: 10.0)
      @poll_seconds = poll_seconds
      @wake_r, @wake_w = IO.pipe
      @backend = build_backend(path)
    end

    # Blocks until a relevant backlog change, an explicit #wake, or the poll
    # timeout. Irrelevant events (e.g. .locks churn) keep the wait going for
    # the remainder of the timeout.
    #
    # @return [Symbol] :change, :wake, or :timeout
    def wait(timeout = @poll_seconds)
      deadline = monotonic + timeout
      loop do
        result = wait_once(deadline)
        return result if result
      end
    end

    # Interrupts a blocked #wait from another thread.
    def wake
      @wake_w.write_nonblock('.')
    rescue IO::WaitWritable, Errno::EPIPE
      nil
    end

    def close
      @backend&.close
      close_io(@wake_w)
      close_io(@wake_r)
    end

    private

    def wait_once(deadline)
      remaining = deadline - monotonic
      return :timeout if remaining <= 0

      ready = IO.select(read_fds, nil, nil, remaining)
      return :timeout if ready.nil?
      return :wake if wake_ready?(ready)

      @backend.relevant_event? ? :change : nil
    end

    def read_fds
      fds = [@wake_r]
      fds << @backend.io if @backend
      fds
    end

    def wake_ready?(ready)
      return false unless ready.first.include?(@wake_r)

      drain_wake
      true
    end

    def drain_wake
      @wake_r.read_nonblock(4096)
    rescue IO::WaitReadable, EOFError
      nil
    end

    def build_backend(path)
      InotifyBackend.new(path, RELEVANT_MASK)
    rescue InotifyBackend::Unavailable, Fiddle::DLError
      nil
    end

    def monotonic
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def close_io(io)
      io.close unless io.nil? || io.closed?
    rescue IOError
      nil
    end

    # Linux inotify backend. Construction raises InotifyBackend::Unavailable
    # when inotify is missing or the watch cannot be set up, so the watcher
    # falls back to polling through its self-pipe timeout.
    class InotifyBackend
      # libc inotify bindings via Fiddle (no external gem).
      module Lib
        extend Fiddle::Importer
        dlload Fiddle.dlopen(nil)
        extern 'int inotify_init1(int)'
        extern 'int inotify_add_watch(int, const char*, uint32_t)'
      end

      # Signals that inotify is unavailable and the watcher should fall back.
      class Unavailable < StandardError; end

      IN_CLOEXEC = 0x00080000
      EVENT_HEADER_SIZE = 16

      attr_reader :io

      def initialize(path, mask)
        fd = Lib.inotify_init1(IN_CLOEXEC)
        guard(fd)
        @io = IO.new(fd, 'r', autoclose: true)
        guard(Lib.inotify_add_watch(fd, path, mask))
      rescue Unavailable, Fiddle::DLError
        @io&.close
        raise Unavailable
      end

      # Drains pending events and reports whether any relevant (non-.locks)
      # entry changed.
      def relevant_event?
        buffer = @io.read_nonblock(8192)
        parse_relevant(buffer)
      rescue IO::WaitReadable, EOFError
        false
      end

      def close
        @io&.close
      rescue IOError
        nil
      end

      private

      def guard(value)
        raise Unavailable if value.negative?
      end

      def parse_relevant(buffer)
        offset = 0
        relevant = false
        while offset + EVENT_HEADER_SIZE <= buffer.bytesize
          _wd, mask, _cookie, len = buffer.byteslice(offset, EVENT_HEADER_SIZE).unpack('L4')
          name = buffer.byteslice(offset + EVENT_HEADER_SIZE, len).to_s.sub(/\0.*/m, '')
          relevant ||= relevant_mask?(mask) && !excluded?(name)
          offset += EVENT_HEADER_SIZE + len
        end
        relevant
      end

      def relevant_mask?(mask)
        (mask & Watcher::RELEVANT_MASK) != 0
      end

      def excluded?(name)
        name == Watcher::EXCLUDED_DIR || name.start_with?("#{Watcher::EXCLUDED_DIR}/")
      end
    end
  end
end
