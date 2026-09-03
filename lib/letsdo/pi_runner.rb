# frozen_string_literal: true

require "json"

module Letsdo
  # Запускает pi в режиме --mode json и по мере генерации отдаёт события
  # стримеру вывода. Код выхода pi пробрасывается наружу.
  #
  # pi --mode json стримит события построчно: разбираем каждую строку как
  # JSON и реагируем на:
  #   message_update (assistantMessageEvent):
  #     text_delta       - фрагмент текста ответа агента → stdout;
  #     toolcall_start   - модель начала выдавать вызов инструмента,
  #                        запоминаем id→имя (фолбэк, см. ниже);
  #   tool_execution_start - инструмент начал выполняться: есть имя и полные
  #                        параметры (например, текст команды bash);
  #   tool_execution_end   - инструмент завершился: result (вывод) и isError;
  #   agent_end            - конец прогона.
  #
  # Заголовок «⚙ имя: параметры» печатается при старте выполнения, результат
  # — при завершении. Если по какой-то причине события tool_execution_* не
  # пришли (старые версии pi и т.п.), при завершении прогона печатаются
  # заглушки «⚙ имя» из запомненных toolcall_start.
  #
  # stdout pi (события) читается нами; stderr pi (его собственный лог)
  # наследуется и уходит в наш stderr.
  class PiRunner
    COMMAND = "pi"
    MODE = "json"
    MESSAGE_UPDATE = "message_update"
    TOOL_EXECUTION_START = "tool_execution_start"
    TOOL_EXECUTION_END = "tool_execution_end"
    AGENT_END = "agent_end"

    # @param prompt [String] текст промпта агента
    # @param flags [Array<String>] дополнительные флаги pi
    # @param streamer [OutputStreamer] куда печатать вывод
    # @param command [String] команда pi (переопределяема для тестов)
    def initialize(prompt:, flags: [], streamer:, command: COMMAND)
      @prompt = prompt
      @flags = flags
      @streamer = streamer
      @command = command
      @pending_tools = {}
    end

    # Запускает pi и дожидается завершения.
    #
    # @return [Integer] код выхода pi (128+сигнал, если pi убит сигналом)
    def run
      cmd = [@command, "--mode", MODE, *@flags, @prompt]
      out_r, out_w = IO.pipe
      pid = Process.spawn(*cmd, out: out_w, err: $stderr)
      out_w.close

      begin
        out_r.set_encoding(Encoding::UTF_8)
        out_r.each_line { |line| handle_line(line) }
      ensure
        out_r.close
        flush_pending_tools
      end

      status = wait_status(pid)
      @streamer.finish
      exit_code(status)
    end

    private

    # Разбирает одну строку потока событий pi и передаёт её стримеру.
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

    # Обработка события обновления сообщения assistant-сообщения.
    def handle_message_update(event)
      payload = event["assistantMessageEvent"]
      return unless payload

      case payload["type"]
      when "text_delta"
        delta = payload["delta"]
        @streamer.text_delta(delta) if delta && !delta.empty?
      when "toolcall_start"
        # Вызов только начал генерироваться: имя известно сразу, параметры
        # появятся вместе с началом выполнения (tool_execution_start).
        id = event["id"] || payload["id"]
        name = event["toolName"] || payload["toolName"] || "tool"
        @pending_tools[id] = name unless id.nil?
      end
    end

    # Результат выполнения инструмента: текст из result.content + признак
    # ошибки. Пустой текст ошибки заменяем понятной формулировкой.
    def handle_tool_execution_end(event)
      text = result_text(event["result"])
      error = event["isError"] == true
      text = "инструмент завершился ошибкой" if (text.nil? || text.empty?) && error
      @streamer.tool_result(text, error: error) if text
    end

    # Собирает текст результата из content-блоков {type: "text"}.
    # Блоки изображений и прочие типы в текст не попадают.
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

    # Заглушки для вызовов без событий выполнения (old pi и т.п.):
    # печатаем «⚙ имя» без параметров. Вызывается и на agent_end, и в
    # ensure после чтения потока; clear защищает от дублей.
    def flush_pending_tools
      @pending_tools.each_value { |name| @streamer.tool_start(name) }
      @pending_tools.clear
    end

    # Игнорирует строки, не являющиеся корректными JSON-событиями.
    def parse_event(line)
      JSON.parse(line)
    rescue JSON::ParserError
      nil
    end

    def wait_status(pid)
      _, status = Process.wait2(pid)
      status
    end

    def exit_code(status)
      return status.exitstatus if status.exitstatus

      status.termsig ? 128 + status.termsig : 1
    end
  end
end