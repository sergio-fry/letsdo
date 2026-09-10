# frozen_string_literal: true

module Letsdo
  module Backends
    # In-process fake backend implementing the Backend protocol for testing.
    # Scripts events via the streamer and exit codes per test configuration.
    class Fake < Backend
      # @param prompt [String] the stripped prompt text
      # @param streamer [Letsdo::OutputStreamer] normalized event sink
      # @param exit_code [Integer, nil] exit code to return when run is called
      # @param events [Array<Hash>] events to emit via the streamer during run
      def initialize(prompt:, streamer:, exit_code: nil, events: [])
        super(prompt: prompt, streamer: streamer)
        @exit_code = exit_code
        @events = events
        @finished = false
        @terminate_now_calls = 0
      end

      def run
        emit_events

        # Emit agent_end implicitly by finishing
        @streamer.finish
        @finished = true

        # Return configured exit code, or 0 for success
        @exit_code || 0
      end

      def terminate_now
        @terminate_now_calls += 1
        @finished = true
      end

      def terminate(*)
        @finished = true
        true
      end

      def pause
        # No-op in fake
      end

      def resume
        # No-op in fake
      end

      def debug(message)
        warn("[letsdo] pi: #{message}") if @debug
      end

      def finished?
        @finished
      end

      attr_reader :terminate_now_calls

      private

      def emit_events
        # Emit scripted events
        @events.each do |event|
          case event['type']
          when 'text_delta'
            @streamer.text_delta(event['delta'])
          when 'tool_start'
            @streamer.tool_start(event['name'], args: event['args'])
          when 'tool_result'
            @streamer.tool_result(event['name'], event['text'], error: event['error'])
          end
        end
      end
    end
  end
end
