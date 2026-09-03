# frozen_string_literal: true

require "json"

module Letsdo
  # Направляет вывод pi по двум потокам:
  #   stdout — только текст ответа агента (text_delta), без служебного;
  #   stderr — служебные строки: вызовы инструментов (имя, параметры,
  #            результат) как прогресс выполнения.
  #
  # Каждая строка-действие пишется с единым префиксом времени HH:MM:SS:
  # по разнице префиксов видно, как давно произошло действие и сколько
  # длился инструмент. Формат служебных строк инструментов:
  #   HH:MM:SS ⚙ имя: параметры       — вызов инструмента одной строкой
  #                                      (для bash — текст команды, для
  #                                      read/write/edit — путь и т.п.);
  #   строки с отступом «  »           — результат выполнения
  #                                      (stdout/stderr), без префикса
  #                                      времени (это данные, не действия);
  #   HH:MM:SS ✓ имя: завершено (Xs)   — завершение инструмента (успех),
  #                                      пишется после блока результата;
  #   HH:MM:SS ✖ имя: ошибка (Xs)      — завершение инструмента (ошибка);
  #   ✖ Ошибка: ...                    — результат-ошибка помечен явно;
  #   … [вывод обрезан: N строк, M]    — большой вывод → сводка-заметка.
  # Запоминает последний символ ответа, чтобы при завершении гарантировать
  # финальный перевод строки — вывод не должен обрываться посередине.
  class OutputStreamer
    # Максимум строк результата инструмента в служебном выводе.
    MAX_RESULT_LINES = 100
    # Максимум символов результата инструмента в служебном выводе.
    MAX_RESULT_CHARS = 4_000
    # Максимум символов краткого представления параметров вызова.
    MAX_ARGS_CHARS = 300

    # @param stdout [IO] поток текста ответа агента
    # @param stderr [IO] поток служебных строк
    # @param clock [Proc] callable → Time, источник времени для префиксов
    #        (инжектируется в тестах для детерминированных HH:MM:SS)
    def initialize(stdout: $stdout, stderr: $stderr, clock: nil)
      @stdout = stdout
      @stderr = stderr
      @clock = clock || -> { Time.now }
      @last_char = nil
      @action_started_at = nil
    end

    # Печатает порцию текста ответа агента немедленно.
    #
    # @param delta [String] очередной фрагмент текста
    def text_delta(delta)
      return if delta.nil? || delta.empty?

      @stdout.write(delta)
      @stdout.flush
      @last_char = delta[-1]
    end

    # Служебная строка о вызове инструмента: префикс времени HH:MM:SS,
    # имя и краткие параметры (например, текст выполняемой команды bash).
    # Одна строка без пустых заготовок, в stderr, чтобы не смешиваться
    # с текстом агента в stdout. Момент вызова запоминается — по нему
    # считается длительность действия в строке завершения.
    #
    # @param name [String] имя инструмента
    # @param args [Hash, String, nil] параметры вызова (событие pi)
    def tool_start(name, args: nil)
      @action_started_at = @clock.call
      line = +"#{timestamp} ⚙ #{name}"
      summary = summarize_args(name, args)
      line << ": #{summary}" if summary
      write_service("#{line}\n")
    end

    # Служебные строки результата инструмента (вывод команды/файла):
    # блок с отступом без префикса времени (данные действия) + строка
    # завершения с префиксом HH:MM:SS, именем, вердиктом и длительностью.
    # Очень большой вывод аккуратно обрезается с заметкой-сводкой, ошибки
    # помечаются явно. Пустой результат даёт только строку завершения.
    #
    # @param name [String] имя инструмента
    # @param text [String] текст результата
    # @param error [Boolean] признак ошибки выполнения
    def tool_result(name, text, error: false)
      out = String.new
      unless text.nil? || text.empty?
        lines = text.lines
        kept, truncated = truncate_result(text)
        kept.each_with_index do |line, index|
          line = line.chomp
          next if line.empty? && index == kept.length - 1 # без хвостовой пустой строки

          prefix = index.zero? ? (error ? "  ✖ Ошибка: " : "  ") : "  "
          out << "#{prefix}#{line}\n"
        end
        out << result_note(lines) if truncated
      end
      out << completion_line(name, error)
      write_service(out)
    end

    # Завершает вывод: если ответ не закончился переводом строки — добавляет
    # его, чтобы следующий вывод терминала не слипся с ответом агента.
    def finish
      return unless @last_char && @last_char != "\n"

      @stdout.write("\n")
      @stdout.flush
    end

    private

    # Единый префикс времени для всех строк-действий: HH:MM:SS.
    #
    # @return [String] локальное время как часы:минуты:секунды
    def timestamp
      @clock.call.strftime("%H:%M:%S")
    end

    # Строка завершения инструмента: префикс времени, вердикт, имя и
    # длительность действия (секунды между вызовом и завершением).
    # Длительность не выводится, если начало действия не зафиксировано
    # (например, результат без предшествующего вызова).
    #
    # @param name [String] имя инструмента
    # @param error [Boolean] признак ошибки
    # @return [String] строка завершения с переводом строки
    def completion_line(name, error)
      mark = error ? "✖" : "✓"
      verdict = error ? "ошибка" : "завершено"
      elapsed = elapsed_seconds
      duration = elapsed ? " (#{format_elapsed(elapsed)})" : ""
      "#{timestamp} #{mark} #{name}: #{verdict}#{duration}\n"
    end

    # Секунды от начала текущего действия до завершения.
    #
    # @return [Float, nil] длительность или nil, если начала не было
    def elapsed_seconds
      return nil unless @action_started_at

      @clock.call - @action_started_at
    end

    # Аккуратная длительность: секунды с одним знаком после запятой до 10с,
    # целые секунды — после.
    def format_elapsed(seconds)
      seconds < 10 ? format("%.1fs", seconds) : "#{seconds.round}s"
    end

    # Обрезает текст результата по лимитам строк и символов.
    #
    # @param text [String] весь текст результата
    # @return [Array(Array<String>, Boolean)] сохранённые строки и признак обрезки
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
      # Одна строка длиннее лимита символов — режем её саму.
      if kept.first && kept.first.length > MAX_RESULT_CHARS
        kept[0] = kept[0].slice(0, MAX_RESULT_CHARS)
        truncated = true
      end
      [kept, truncated]
    end

    # Заметка-сводка об обрезанном результате.
    def result_note(lines)
      total_lines = lines.length
      total_chars = lines.sum(&:length)
      lines_word = plural(total_lines, one: "строка", few: "строки", many: "строк")
      chars_word = plural(total_chars, one: "символ", few: "символа", many: "символов")
      "  … [вывод обрезан: #{total_lines} #{lines_word}, #{total_chars} #{chars_word}]\n"
    end

    # Русское склонение существительного после числа.
    def plural(count, one:, few:, many:)
      return many if count % 100 >= 11 && count % 100 <= 14

      case count % 10
      when 1 then one
      when 2..4 then few
      else many
      end
    end

    # Краткое однострочное представление параметров вызова инструмента.
    #
    # @param name [String] имя инструмента
    # @param args [Hash, String, nil] параметры вызова
    # @return [String, nil] строка параметров или nil (ничего не печатать)
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

    # Диапазон строк read (offset/limit) в виде ":N-M", если задан.
    def read_range(args)
      return nil unless args.is_a?(Hash)

      offset = args["offset"]
      return nil unless offset

      limit = args["limit"]
      limit ? ":#{offset}-#{offset + limit - 1}" : ":#{offset}"
    end

    # Значение параметра вызова как строка; nil, если нет.
    def args_value(args, key)
      return nil unless args.is_a?(Hash)

      value = args[key]
      value.nil? ? nil : value.to_s
    end

    # Универсальное представление параметров (прочие инструменты):
    # краткий JSON одной строкой.
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

    # Схлопывает пробельные символы в одну строку и режет по лимиту.
    def one_line(value, max: MAX_ARGS_CHARS)
      return nil if value.nil?

      text = value.to_s.gsub(/\s+/, " ").strip
      return nil if text.empty?

      text.length > max ? "#{text.slice(0, max)}…" : text
    end

    # Пишет служебную строку в stderr и сразу сбрасывает буфер,
    # чтобы вывод появлялся по мере выполнения.
    def write_service(text)
      @stderr.write(text)
      @stderr.flush
    end
  end
end