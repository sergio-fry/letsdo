# frozen_string_literal: true

require 'json'

module Letsdo
  # Routes pi output: agent text on stdout, tool lines on stderr (or a log).
  class OutputStreamer
    MAX_RESULT_LINES = 100
    MAX_RESULT_CHARS = 4_000
    MAX_ARGS_CHARS = 300

    def initialize(stdout: $stdout, stderr: $stderr, log: nil, clock: nil)
      @stdout = stdout
      @stderr = stderr
      @log = log
      @clock = clock || -> { Time.now }
      @last_char = nil
      @action_started_at = nil
    end

    def text_delta(delta)
      return if delta.nil? || delta.empty?

      text_sink.write(delta)
      text_sink.flush unless @log
      @last_char = delta[-1]
    end

    def tool_start(name, args: nil)
      @action_started_at = @clock.call
      line = +"#{timestamp} ⚙ #{name}"
      summary = ArgSummary.call(name, args)
      line << ": #{summary}" if summary
      write_service("#{line}\n")
    end

    def tool_result(name, text, error: false)
      write_service(ResultBlock.call(text, error: error, completion: completion_line(name, error)))
    end

    def finish
      return unless @last_char && @last_char != "\n"

      text_sink.write("\n")
      text_sink.flush unless @log
    end

    private

    def timestamp
      @clock.call.strftime('%H:%M:%S')
    end

    def completion_line(name, error)
      mark = error ? '✖' : '✓'
      verdict = error ? 'error' : 'done'
      elapsed = elapsed_seconds
      duration = elapsed ? " (#{format_elapsed(elapsed)})" : ''
      "#{timestamp} #{mark} #{name}: #{verdict}#{duration}\n"
    end

    def elapsed_seconds
      return nil unless @action_started_at

      @clock.call - @action_started_at
    end

    def format_elapsed(seconds)
      seconds < 10 ? format('%.1fs', seconds) : "#{seconds.round}s"
    end

    def write_service(text)
      if @log
        @log.write(text)
      else
        @stderr.write(text)
        @stderr.flush
      end
    end

    def text_sink
      @log || @stdout
    end
  end
end

require_relative 'output_streamer/arg_summary'
require_relative 'output_streamer/result_block'
