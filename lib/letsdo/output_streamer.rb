# frozen_string_literal: true

require "json"

module Letsdo
  # Routes pi output across two streams:
  #   stdout — only the agent's answer text (text_delta), no service lines;
  #   stderr — service lines: tool calls (name, arguments, result) as
  #            execution progress.
  #
  # Every action line gets a shared HH:MM:SS time prefix: the difference
  # between prefixes shows how long ago an action happened and how long
  # a tool ran. Format of service tool lines:
  #   HH:MM:SS ⚙ name: arguments    — tool call on one line (for bash the
  #                                   command text, for read/write/edit the
  #                                   path, etc.);
  #   indented "  " lines           — execution result (stdout/stderr),
  #                                   no time prefix (data, not actions);
  #   HH:MM:SS ✓ name: done (Xs)    — tool completion (success), printed
  #                                   after the result block;
  #   HH:MM:SS ✖ name: error (Xs)   — tool completion (error);
  #   ✖ Error: ...                  — error result marked explicitly;
  #   … [output truncated: N lines, M] — big output → summary note.
  # Remembers the last response character so that on finish a final newline
  # is guaranteed — output must not break in the middle.
  class OutputStreamer
    # Max lines of a tool result in service output.
    MAX_RESULT_LINES = 100
    # Max characters of a tool result in service output.
    MAX_RESULT_CHARS = 4_000
    # Max characters of a short call-arguments representation.
    MAX_ARGS_CHARS = 300

    # @param stdout [IO] stream for the agent's answer text
    # @param stderr [IO] stream for service lines
    # @param clock [Proc] callable → Time, the source of time for prefixes
    #        (injected in tests for deterministic HH:MM:SS)
    def initialize(stdout: $stdout, stderr: $stderr, clock: nil)
      @stdout = stdout
      @stderr = stderr
      @clock = clock || -> { Time.now }
      @last_char = nil
      @action_started_at = nil
    end

    # Prints a chunk of the agent's answer text immediately.
    #
    # @param delta [String] the next text fragment
    def text_delta(delta)
      return if delta.nil? || delta.empty?

      @stdout.write(delta)
      @stdout.flush
      @last_char = delta[-1]
    end

    # A service line about a tool call: HH:MM:SS time prefix, tool name and
    # short arguments (e.g. the executed bash command text). One line without
    # empty placeholders, to stderr so it does not mix with the agent text
    # on stdout. The call moment is remembered — the action duration in the
    # completion line is measured from it.
    #
    # @param name [String] tool name
    # @param args [Hash, String, nil] call arguments (pi event)
    def tool_start(name, args: nil)
      @action_started_at = @clock.call
      line = +"#{timestamp} ⚙ #{name}"
      summary = summarize_args(name, args)
      line << ": #{summary}" if summary
      write_service("#{line}\n")
    end

    # Service lines of the tool result (command/file output): an indented
    # block without a time prefix (action data) plus a completion line with
    # the HH:MM:SS prefix, name, verdict and duration. Very large output is
    # trimmed neatly with a summary note, errors are marked explicitly.
    # An empty result yields only the completion line.
    #
    # @param name [String] tool name
    # @param text [String] result text
    # @param error [Boolean] whether the execution failed
    def tool_result(name, text, error: false)
      out = String.new
      unless text.nil? || text.empty?
        lines = text.lines
        kept, truncated = truncate_result(text)
        kept.each_with_index do |line, index|
          line = line.chomp
          next if line.empty? && index == kept.length - 1 # no trailing empty line

          prefix = index.zero? ? (error ? "  ✖ Error: " : "  ") : "  "
          out << "#{prefix}#{line}\n"
        end
        out << result_note(lines) if truncated
      end
      out << completion_line(name, error)
      write_service(out)
    end

    # Finishes the output: if the answer did not end with a newline — adds
    # one so the next terminal output does not stick to the agent's answer.
    def finish
      return unless @last_char && @last_char != "\n"

      @stdout.write("\n")
      @stdout.flush
    end

    private

    # Shared time prefix for all action lines: HH:MM:SS.
    #
    # @return [String] local time as hours:minutes:seconds
    def timestamp
      @clock.call.strftime("%H:%M:%S")
    end

    # Tool completion line: time prefix, verdict, name and action duration
    # (seconds between call and completion). The duration is not printed
    # when no action start was recorded (e.g. a result without a preceding
    # call).
    #
    # @param name [String] tool name
    # @param error [Boolean] whether the execution failed
    # @return [String] completion line with a trailing newline
    def completion_line(name, error)
      mark = error ? "✖" : "✓"
      verdict = error ? "error" : "done"
      elapsed = elapsed_seconds
      duration = elapsed ? " (#{format_elapsed(elapsed)})" : ""
      "#{timestamp} #{mark} #{name}: #{verdict}#{duration}\n"
    end

    # Seconds from the current action start to its completion.
    #
    # @return [Float, nil] duration, or nil if there was no start
    def elapsed_seconds
      return nil unless @action_started_at

      @clock.call - @action_started_at
    end

    # A neat duration: seconds with one decimal place up to 10s, whole
    # seconds after.
    def format_elapsed(seconds)
      seconds < 10 ? format("%.1fs", seconds) : "#{seconds.round}s"
    end

    # Truncates the result text by line and character limits.
    #
    # @param text [String] the whole result text
    # @return [Array(Array<String>, Boolean)] kept lines and truncation flag
    def truncate_result(text)
      lines = text.lines
      kept = []
      chars = 0
      truncated = false
      lines.each do |line|
        if kept.length >= MAX_RESULT_LINES || (!kept.empty? && chars + line.length > MAX_RESULT_CHARS)
          truncated = true
          break
        end
        kept << line
        chars += line.length
      end
      # A single line longer than the char limit — cut the line itself.
      if kept.first && kept.first.length > MAX_RESULT_CHARS
        kept[0] = kept[0].slice(0, MAX_RESULT_CHARS)
        truncated = true
      end
      [kept, truncated]
    end

    # Summary note about the truncated result.
    def result_note(lines)
      total_lines = lines.length
      total_chars = lines.sum(&:length)
      lines_word = plural(total_lines, "line", "lines")
      chars_word = plural(total_chars, "character", "characters")
      "  … [output truncated: #{total_lines} #{lines_word}, #{total_chars} #{chars_word}]\n"
    end

    # English singular/plural for a noun after a number.
    def plural(count, singular, plural_form)
      count == 1 ? singular : plural_form
    end

    # Short one-line representation of the tool call arguments.
    #
    # @param name [String] tool name
    # @param args [Hash, String, nil] call arguments
    # @return [String, nil] arguments string or nil (print nothing)
    def summarize_args(name, args)
      case name
      when "bash", "powershell"
        one_line(args_value(args, "command"))
      when "read"
        path = args_value(args, "path") || args_value(args, "file_path")
        return nil unless path

        range = read_range(args)
        "#{path}#{range}"
      when "write", "edit", "find", "ls"
        args_value(args, "path") || args_value(args, "file_path")
      when "grep"
        pattern = one_line(args_value(args, "pattern"))
        path = args_value(args, "path") || args_value(args, "file_path")
        return nil unless pattern

        path ? "#{pattern} #{path}" : pattern
      else
        summarize_generic(args)
      end
    end

    # Read line range (offset/limit) as ":N-M", when given.
    def read_range(args)
      return nil unless args.is_a?(Hash)

      offset = args["offset"]
      return nil unless offset

      limit = args["limit"]
      limit ? ":#{offset}-#{offset + limit - 1}" : ":#{offset}"
    end

    # Tool argument value as a string; nil when absent.
    def args_value(args, key)
      return nil unless args.is_a?(Hash)

      value = args[key]
      value.nil? ? nil : value.to_s
    end

    # Universal arguments representation (other tools): short JSON on one line.
    def summarize_generic(args)
      return nil if args.nil? || (args.is_a?(Hash) && args.empty?)

      text =
        case args
        when String then args
        when Hash then JSON.generate(args)
        else args.to_s
        end
      one_line(text)
    end

    # Collapses whitespace into a single line and cuts by the limit.
    def one_line(value, max: MAX_ARGS_CHARS)
      return nil if value.nil?

      text = value.to_s.gsub(/\s+/, " ").strip
      return nil if text.empty?

      text.length > max ? "#{text.slice(0, max)}…" : text
    end

    # Writes a service line to stderr and flushes immediately so output
    # appears as it is produced.
    def write_service(text)
      @stderr.write(text)
      @stderr.flush
    end
  end
end