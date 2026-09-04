# frozen_string_literal: true

module Letsdo
  class OutputStreamer
    # Truncates and prefixes a tool result block.
    class ResultBlock
      MAX_LINES = OutputStreamer::MAX_RESULT_LINES
      MAX_CHARS = OutputStreamer::MAX_RESULT_CHARS

      def self.call(text, error:, completion:)
        new(text, error: error, completion: completion).to_s
      end

      def initialize(text, error:, completion:)
        @text = text
        @error = error
        @completion = completion
      end

      def to_s
        "#{body}#{@completion}"
      end

      def body
        return '' if @text.nil? || @text.empty?

        kept, truncated = truncate(@text)
        out = format_lines(kept)
        out << note(@text.lines) if truncated
        out
      end

      def format_lines(kept)
        out = String.new
        kept.each_with_index do |line, index|
          line = line.chomp
          next if line.empty? && index == kept.length - 1

          out << "#{line_prefix(index)}#{line}\n"
        end
        out
      end

      def line_prefix(index)
        index.zero? && @error ? '  ✖ Error: ' : '  '
      end

      def truncate(text)
        kept, truncated = collect_lines(text.lines)
        clip_first_line(kept, truncated)
      end

      def collect_lines(lines)
        kept = []
        chars = 0
        lines.each do |line|
          return [kept, true] if over_limit?(kept, chars, line)

          kept << line
          chars += line.length
        end
        [kept, false]
      end

      def over_limit?(kept, chars, line)
        kept.length >= MAX_LINES || (!kept.empty? && chars + line.length > MAX_CHARS)
      end

      def clip_first_line(kept, truncated)
        if kept.first && kept.first.length > MAX_CHARS
          kept[0] = kept[0].slice(0, MAX_CHARS)
          truncated = true
        end
        [kept, truncated]
      end

      def note(lines)
        total_lines = lines.length
        total_chars = lines.sum(&:length)
        "  … [output truncated: #{total_lines} #{plural(total_lines, 'line')}, " \
          "#{total_chars} #{plural(total_chars, 'character')}]\n"
      end

      def plural(count, word)
        count == 1 ? word : "#{word}s"
      end
    end
  end
end
