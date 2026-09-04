# frozen_string_literal: true

require "json"

module Letsdo
  # Runs pi in --mode json and hands events to the output streamer as they
  # are generated. The pi exit code is propagated outward.
  #
  # pi --mode json streams events line by line: each line is parsed as JSON
  # and reacted to:
  #   message_update (assistantMessageEvent):
  #     text_delta       - a fragment of the agent's answer text → stdout;
  #     toolcall_start   - the model started emitting a tool call,
  #                        id→name is remembered (fallback, see below);
  #   tool_execution_start - a tool started executing: name and full
  #                        arguments are available (e.g. bash command text);
  #   tool_execution_end   - a tool finished: result (output) and isError;
  #   agent_end            - the end of the run.
  #
  # The "HH:MM:SS ⚙ name: arguments" header is printed at execution start,
  # the result and "✓/✖ name" completion line — at completion. If for some
  # reason no tool_execution_* events arrive (older pi versions, etc.), "⚙ name"
  # placeholders from remembered toolcall_start events are printed at the end
  # of the run.
  #
  # pi stdout (events) is read by us; pi stderr (its own log) is inherited
  # and goes to our stderr.
  class PiRunner
    COMMAND = "pi"
    MODE = "json"
    MESSAGE_UPDATE = "message_update"
    TOOL_EXECUTION_START = "tool_execution_start"
    TOOL_EXECUTION_END = "tool_execution_end"
    AGENT_END = "agent_end"

    # @param prompt [String] agent prompt text
    # @param flags [Array<String>] extra pi flags
    # @param streamer [OutputStreamer] where to print output
    # @param command [String] the pi command (overridable for tests)
    # @param debug [Boolean, nil] trace [letsdo] lines to stderr; nil = LETSDO_DEBUG
    def initialize(prompt:, flags: [], streamer:, command: COMMAND, debug: nil)
      @prompt = prompt
      @flags = flags
      @streamer = streamer
      @command = command
      @pending_tools = {}
      @debug = debug.nil? ? ENV["LETSDO_DEBUG"] == "1" : debug
    end

    # Runs pi and waits for completion.
    #
    # pi is spawned in its own process group so the orchestrator can stop it
    # (signal handlers interrupt the loop, not the pi child directly): a stop
    # terminates the whole group via #terminate.
    #
    # The event stream is read on the main thread. A stop signal arrives as
    # Letsdo::Stopped raised by the trap (see Letsdo::AgentLoop#on_signal):
    # the raise interrupts the blocking read directly — no reader threads,
    # polls or flags. Note for future work on this file: CRuby 4.0 (M:N
    # threads) here does not execute traps while the main thread is in
    # Thread#join, defers them with another thread blocked on IO, and does
    # not wake IO.select on pipe data — the raise-in-trap approach avoids
    # all of it.
    #
    # @return [Integer] pi exit code (128+signal if pi was killed by a signal)
    def run
      cmd = [@command, "--mode", MODE, *@flags, @prompt]
      out_r, out_w = IO.pipe
      @pid = Process.spawn(*cmd, out: out_w, err: $stderr, pgroup: true)
      out_w.close
      debug("spawned pid=#{@pid} (own group)")

      begin
        read_pi_stream(out_r)
      rescue Letsdo::Stopped
        # The signal handler already sent SIGTERM to the pi group; make sure
        # it is gone (grace loop here runs in the main context, not a trap)
        # and reap it before propagating the stop.
        debug("stopped by signal, terminating pi")
        terminate
        status = wait_status(@pid)
        @streamer.finish
        raise
      ensure
        begin
          out_r.close
        rescue IOError
          nil
        end
        flush_pending_tools
      end

      status = wait_status(@pid)
      @streamer.finish
      debug("exit status=#{status.inspect} code=#{exit_code(status)}")
      exit_code(status)
    ensure
      @pid = nil
    end

    def debug(message)
      warn("[letsdo] pi: #{message}") if @debug
    end

    # One-shot SIGTERM to the pi process group for a signal handler: no
    # waits, sleeps or IO — safe inside a trap. The caller reaps the child
    # afterwards (see #run).
    def terminate_now
      pid = @pid
      send_signal("TERM", pid) if pid
    end

    # Freezes pi mid-run: SIGSTOP to its process group. The whole group
    # (pi + any tool children) stops at the kernel level; letsdo's reader
    # simply stays blocked on the pipe until #resume. Safe to call when no
    # pi is running or the group is already gone (no-op, see #send_signal).
    def pause
      pid = @pid
      send_signal("STOP", pid) if pid
    end

    # Resumes a paused pi: SIGCONT to its process group. A no-op on a
    # process that is not stopped (SIGCONT is ignored by default then)
    # and when the group is gone (see #send_signal).
    def resume
      pid = @pid
      send_signal("CONT", pid) if pid
    end

    # Stops a running pi: SIGCONT, then SIGTERM to its process group, then
    # SIGKILL after the grace period if it did not exit. Safe to call when
    # the run already finished (no-op).
    #
    # SIGCONT first: a SIGSTOPped process does not process SIGTERM, so a
    # paused run would otherwise stall for the whole grace period before
    # SIGKILL. SIGCONT on a non-stopped process is a no-op, so it is safe
    # to send unconditionally.
    #
    # @param signal [String] the first signal to send
    # @param grace [Float] seconds to wait before falling back to SIGKILL
    def terminate(signal: "TERM", grace: 3.0, tick: 0.05)
      pid = @pid
      return true unless pid

      send_signal("CONT", pid)
      send_signal(signal, pid)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + grace
      loop do
        break unless alive?(pid)

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          send_signal("KILL", pid)
          break
        end
        sleep(tick)
      end
      true
    end

    private

    # Reads the pi event stream until EOF. Runs on the main thread; a stop
    # signal interrupts it via Letsdo::Stopped raised from the trap.
    def read_pi_stream(out_r)
      out_r.each_line { |line| handle_line(line) }
      debug("stream: EOF")
    end

    # Parses one line of the pi event stream and passes it to the streamer.
    def handle_line(line)
      line = line.strip
      return if line.empty?

      event = parse_event(line)
      return unless event

      case event["type"]
      when MESSAGE_UPDATE
        handle_message_update(event)
      when TOOL_EXECUTION_START
        @pending_tools.delete(event["toolCallId"])
        @streamer.tool_start(event["toolName"] || "tool", args: event["args"])
      when TOOL_EXECUTION_END
        handle_tool_execution_end(event)
      when AGENT_END
        flush_pending_tools
      end
    end

    # Handles an assistant message update event.
    def handle_message_update(event)
      payload = event["assistantMessageEvent"]
      return unless payload

      case payload["type"]
      when "text_delta"
        delta = payload["delta"]
        @streamer.text_delta(delta) if delta && !delta.empty?
      when "toolcall_start"
        # The call has just started to be generated: the name is known
        # immediately, arguments will arrive with the execution start
        # (tool_execution_start).
        id = event["id"] || payload["id"]
        name = event["toolName"] || payload["toolName"] || "tool"
        @pending_tools[id] = name unless id.nil?
      end
    end

    # Tool execution result: text from result.content plus the error flag.
    # An empty error text is replaced with a clear wording. The completion
    # line is always printed (even for an empty result), so that the action
    # completion is visible in the service output.
    def handle_tool_execution_end(event)
      name = event["toolName"] || "tool"
      text = result_text(event["result"])
      error = event["isError"] == true
      text = "tool failed with an error" if (text.nil? || text.empty?) && error
      @streamer.tool_result(name, text, error: error)
    end

    # Collects the result text from {type: "text"} content blocks.
    # Image blocks and other types do not get into the text.
    def result_text(result)
      return nil unless result.is_a?(Hash)

      content = result["content"]
      return nil unless content.is_a?(Array)

      parts = content.filter_map do |block|
        next nil unless block.is_a?(Hash)

        text = block["text"]
        text if text.is_a?(String) && !text.empty? &&
                (block["type"] == "text" || !block.key?("type"))
      end
      text = parts.join
      text.empty? ? nil : text
    end

    # Placeholders for calls without execution events (old pi, etc.):
    # prints "⚙ name" without arguments. Called both on agent_end and in
    # the ensure block after reading the stream; clear protects against
    # duplicates.
    def flush_pending_tools
      @pending_tools.each_value { |name| @streamer.tool_start(name) }
      @pending_tools.clear
    end

    # Ignores lines that are not valid JSON events.
    def parse_event(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    def wait_status(pid)
      _, status = Process.wait2(pid)
      status
    end

    # Sends a signal to the pi process group. Missing/killed groups are
    # silently ignored.
    def send_signal(signal, pid)
      Process.kill(signal, -pid)
    rescue Errno::ESRCH, Errno::EPERM
      nil
    end

    # Whether the pi process still exists (does not reap it).
    def alive?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH, Errno::EPERM
      false
    end

    def exit_code(status)
      return status.exitstatus if status.exitstatus

      status.termsig ? 128 + status.termsig : 1
    end
  end
end