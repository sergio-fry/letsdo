# frozen_string_literal: true

module Letsdo
  # Pi JSON event-stream handlers used by PiRunner.
  module PiRunnerEvents
    private

    def read_pi_stream(out_r)
      out_r.each_line { |line| handle_line(line) }
      debug('stream: EOF')
    end

    def handle_line(line)
      line = line.strip
      return if line.empty?

      event = parse_event(line)
      dispatch_event(event) if event
    end

    def dispatch_event(event)
      case event['type']
      when 'message_update' then handle_message_update(event)
      when 'tool_execution_start' then handle_tool_start(event)
      when 'tool_execution_end' then handle_tool_execution_end(event)
      when 'agent_end' then flush_pending_tools
      end
    end

    def handle_tool_start(event)
      @pending_tools.delete(event['toolCallId'])
      @streamer.tool_start(event['toolName'] || 'tool', args: event['args'])
    end

    def handle_message_update(event)
      payload = event['assistantMessageEvent']
      return unless payload

      handle_text_delta(payload) || remember_toolcall(event, payload)
    end

    def handle_text_delta(payload)
      return unless payload['type'] == 'text_delta'

      delta = payload['delta']
      @streamer.text_delta(delta) if delta && !delta.empty?
      true
    end

    def remember_toolcall(event, payload)
      return unless payload['type'] == 'toolcall_start'

      id = event['id'] || payload['id']
      name = event['toolName'] || payload['toolName'] || 'tool'
      @pending_tools[id] = name unless id.nil?
    end

    def handle_tool_execution_end(event)
      name = event['toolName'] || 'tool'
      text = result_text(event['result'])
      error = event['isError'] == true
      text = 'tool failed with an error' if text_missing?(text) && error
      @streamer.tool_result(name, text, error: error)
    end

    def text_missing?(text)
      text.nil? || text.empty?
    end

    def result_text(result)
      return nil unless result.is_a?(Hash)

      content = result['content']
      return nil unless content.is_a?(Array)

      joined = content.filter_map { |block| text_block(block) }.join
      joined.empty? ? nil : joined
    end

    def text_block(block)
      return nil unless block.is_a?(Hash)

      text = block['text']
      return nil unless text.is_a?(String) && !text.empty?
      return nil unless block['type'] == 'text' || !block.key?('type')

      text
    end

    def flush_pending_tools
      @pending_tools.each_value { |name| @streamer.tool_start(name) }
      @pending_tools.clear
    end

    def parse_event(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end
  end
end
