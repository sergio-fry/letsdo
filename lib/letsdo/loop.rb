# frozen_string_literal: true

module Letsdo
  # Оркестратор: пока в бэклоге есть открытые задачи, назначенные агенту,
  # запускает агента (один прогон = одна задача). Когда задач нет — ждёт и
  # проверяет снова. Остановка — только снаружи: #stop (обычно обработчиком
  # SIGINT/SIGTERM, как в bin/agent-loop).
  #
  # Провайдер задач и раннер инжектируются, чтобы цикл был тестируем без
  # реального бэклога и pi; по умолчанию они собираются из окружения проекта
  # (backlog CLI + Letsdo::Agent).
  class Loop
    # @param task_provider [Proc] callable → Array открытых задач
    #        (пусто = задач нет; nil = состояние бэклога не читается,
    #        в этом случае цикл не запускает агента и повторяет проверку)
    # @param run_task [Proc] callable(задача) → код выхода прогона агента
    # @param wait_seconds [Float] интервал ожидания при отсутствии задач
    # @param sleeper [Proc] callable(Float) → ожидание (инжектируется в тестах)
    def initialize(task_provider:, run_task:, wait_seconds: 10.0, sleeper: nil)
      @task_provider = task_provider
      @run_task = run_task
      @wait_seconds = wait_seconds
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      @stopped = false
    end

    # Запрашивает остановку после текущего шага.
    def stop
      @stopped = true
    end

    def stopped?
      @stopped
    end

    # Запускает цикл; завершается только по #stop.
    #
    # @return [Integer] количество выполненных прогонов агента
    def run
      runs = 0
      until @stopped
        tasks = @task_provider.call
        if tasks.nil? || tasks.empty?
          @sleeper.call(@wait_seconds)
          next
        end

        tasks.each do |task|
          break if @stopped

          @run_task.call(task)
          runs += 1
        end
      end
      runs
    end
  end
end