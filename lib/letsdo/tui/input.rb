# frozen_string_literal: true

require 'stringio'

module Letsdo
  module Tui
    # Non-blocking keyboard input for the TUI: wraps tty-reader and maps
    # escape sequences to plain symbols (:up, :down, :page_up, :page_down,
    # :home, :end, :p, :r, :q, :ctrl_c). Returns nil when no key is waiting
    # within the poll timeout, so the caller can repaint on a 1s timer.
    #
    # Ctrl-C is read as a key (:ctrl_c → quit) instead of raising: the
    # tty-reader raw mode disables the terminal's SIGINT generation, and
    # external SIGINT/SIGTERM still go through the loop's signal path.
    #
    # Tests inject a pipe with the raw escape bytes — tty-reader's
    # mode helpers no-op on non-tty inputs, so no real TTY is needed.
    # tty-reader's unused echo stream is a StringIO (stdlib, required here).
    class Input
      # Poll timeout for readable input, seconds.
      POLL_TIMEOUT = 0.1

      KEY_BY_VALUE = {
        'p' => :p, 'r' => :r, 'q' => :q,
        "\u0003" => :ctrl_c,
        "\e[A" => :up, "\eOA" => :up,
        "\e[B" => :down, "\eOB" => :down,
        "\e[5~" => :page_up,
        "\e[6~" => :page_down,
        "\e[H" => :home, "\e[1~" => :home, "\e[7~" => :home, "\eOH" => :home,
        "\e[F" => :end, "\e[4~" => :end, "\e[8~" => :end, "\eOF" => :end
      }.freeze

      # The keyboard stream (exposed so the session can wrap it in raw mode).
      attr_reader :stdin

      # @param stdin [IO] the keyboard stream (a terminal when engaged)
      # @param poll_timeout [Numeric] nil-poll interval for non-tty inputs
      def initialize(stdin:, poll_timeout: POLL_TIMEOUT)
        require 'tty-reader'

        @stdin = stdin
        @poll_timeout = poll_timeout
        @reader = TTY::Reader.new(input: stdin, output: StringIO.new,
                                  interrupt: :noop, track_history: false)
      end

      # The next key, or nil when nothing was pressed in time.
      #
      # @return [Symbol, nil]
      def next_key
        return nil unless ready?

        value = @reader.read_keypress(echo: false, raw: false, nonblock: false)
        return nil if value.nil?

        # tty-reader 0.9 only continues CSI (`\e[…`); SS3 (`\eO…`) stops
        # after `\eO`. Pull the final byte so `\eOA` / `\eOH` / `\eOF` map.
        if value == "\eO" && (final = ss3_final_byte)
          value += final
        end

        KEY_BY_VALUE[value]
      end

      private

      # Whether a key is available now (bounded wait). Real terminals use
      # wait_readable; otherwise eof?.
      def ready?
        if @stdin.respond_to?(:wait_readable)
          @stdin.wait_readable(@poll_timeout)
        else
          !@stdin.eof?
        end
      end

      def ss3_final_byte
        return nil unless byte_waiting?

        @stdin.getc
      end

      def byte_waiting?
        if @stdin.respond_to?(:wait_readable)
          @stdin.wait_readable(0)
        else
          !@stdin.eof?
        end
      end
    end
  end
end
