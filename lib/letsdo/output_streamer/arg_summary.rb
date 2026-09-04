# frozen_string_literal: true

require 'json'

module Letsdo
  class OutputStreamer
    # Short one-line representations of tool-call arguments.
    class ArgSummary
      MAX_ARGS_CHARS = OutputStreamer::MAX_ARGS_CHARS

      def self.call(name, args)
        new(name, args).to_s
      end

      def initialize(name, args)
        @name = name
        @args = args
      end

      def to_s
        case @name
        when 'bash', 'powershell' then one_line(value('command'))
        when 'read' then read_summary
        when 'write', 'edit', 'find', 'ls' then value('path') || value('file_path')
        when 'grep' then grep_summary
        else generic
        end
      end

      def read_summary
        path = value('path') || value('file_path')
        path && "#{path}#{read_range}"
      end

      def grep_summary
        pattern = one_line(value('pattern'))
        return nil unless pattern

        path = value('path') || value('file_path')
        path ? "#{pattern} #{path}" : pattern
      end

      def generic
        return nil if @args.nil? || (@args.is_a?(Hash) && @args.empty?)

        one_line(generic_text)
      end

      def generic_text
        case @args
        when String then @args
        when Hash then JSON.generate(@args)
        else @args.to_s
        end
      end

      def read_range
        return nil unless @args.is_a?(Hash)

        offset = @args['offset']
        return nil unless offset

        limit = @args['limit']
        limit ? ":#{offset}-#{offset + limit - 1}" : ":#{offset}"
      end

      def value(key)
        @args.is_a?(Hash) ? @args[key]&.to_s : nil
      end

      def one_line(raw, max: MAX_ARGS_CHARS)
        return nil if raw.nil?

        text = raw.to_s.gsub(/\s+/, ' ').strip
        return nil if text.empty?

        text.length > max ? "#{text.slice(0, max)}…" : text
      end
    end
  end
end
