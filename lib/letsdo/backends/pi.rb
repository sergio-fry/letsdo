# frozen_string_literal: true

require 'json'
require_relative 'pi/events'

module Letsdo
  module Backends
    # Runs pi --mode json and hands normalized events to the streamer.
    #
    # Pi-specific knowledge lives here (spawn command, JSON event schema,
    # exit-code mapping, process-group termination) -- the business layer
    # sees only the backend protocol.
    class Pi < Backend
      COMMAND = 'pi'
      MODE    = 'json'

      def initialize(prompt:, streamer:, **options)
        flags   = options.fetch(:flags, [])
        command = options.fetch(:command, COMMAND)
        model   = options[:model]
        super(prompt: prompt, streamer: streamer, debug: options[:debug],
              config: options[:config])
        @command = command
        @flags = flags.dup
        @flags.unshift('--model', model) if model && !@flags.include?('--model')
        @pending_tools = {}
      end

      def run
        out_r = spawn_pi
        drain_stream(out_r)
        finish_run
      ensure
        @pid = nil
        @reaped_status = nil
      end

      private

      # spawn / drain / finish

      def spawn_pi
        cmd = [@command, '--mode', MODE, *@flags, @prompt]
        out_r, out_w = IO.pipe
        @pid = Process.spawn(*cmd, out: out_w, err: $stderr, pgroup: true)
        out_w.close
        debug("spawned pid=#{@pid} (own group)")
        out_r
      end

      def drain_stream(out_r)
        read_pi_stream(out_r)
      rescue Letsdo::Stopped
        debug('stopped by signal, terminating pi')
        terminate
        wait_status(@pid)
        @streamer.finish
        raise
      ensure
        close_pipe(out_r)
        flush_pending_tools
      end

      def close_pipe(out_r)
        out_r.close
      rescue IOError
        nil
      end

      def finish_run
        status = wait_status(@pid)
        @streamer.finish
        debug("exit status=#{status.inspect} code=#{exit_code(status)}")
        exit_code(status)
      end

      include PiEvents
    end
  end
end
