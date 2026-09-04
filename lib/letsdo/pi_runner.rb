# frozen_string_literal: true

require 'json'

module Letsdo
  # Runs pi in --mode json and hands events to the output streamer.
  class PiRunner
    COMMAND = 'pi'
    MODE = 'json'
    MESSAGE_UPDATE = 'message_update'
    TOOL_EXECUTION_START = 'tool_execution_start'
    TOOL_EXECUTION_END = 'tool_execution_end'
    AGENT_END = 'agent_end'
  end
end

require_relative 'pi_runner/events'
require_relative 'pi_runner/process'

module Letsdo
  # Pi process spawn, stream drain, and pause/resume signals.
  class PiRunner
    include PiRunnerEvents
    include PiRunnerProcess

    def initialize(prompt:, streamer:, **opts)
      @prompt = prompt
      @streamer = streamer
      @flags = opts.fetch(:flags, [])
      @command = opts.fetch(:command, COMMAND)
      @pending_tools = {}
      @reaped_status = nil
      @debug = opts[:debug].nil? ? ENV['LETSDO_DEBUG'] == '1' : opts[:debug]
    end

    def run
      out_r = spawn_pi
      drain_stream(out_r)
      finish_run
    ensure
      @pid = nil
      @reaped_status = nil
    end

    def debug(message)
      warn("[letsdo] pi: #{message}") if @debug
    end

    def terminate_now
      pid = @pid
      send_signal('TERM', pid) if pid
    end

    def pause
      pid = @pid
      send_signal('STOP', pid) if pid
    end

    def resume
      pid = @pid
      send_signal('CONT', pid) if pid
    end

    private

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
  end
end
