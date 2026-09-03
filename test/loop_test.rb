# frozen_string_literal: true

require_relative "test_helper"
require "stringio"

class LoopTest < Minitest::Test
  # Провайдер задач, отдающий задачи по расписанию:
  #   schedule = [[...], [...]] — какие задачи вернуть на каждый вызов.
  def scheduled_provider(schedule)
    index = 0
    lambda do
      result = index < schedule.length ? schedule[index] : []
      index += 1
      result
    end
  end

  # Создаёт цикл, останавливающийся сразу после первого ожидания.
  def loop_that_stops_after_first_wait(provider:, runs:, wait_seconds: 0.01)
    loop_obj = nil
    sleeper = lambda do |seconds|
      runs[:waits] << seconds
      loop_obj.stop
    end
    loop_obj = Letsdo::Loop.new(
      task_provider: provider,
      run_task: ->(task) { runs[:tasks] << task },
      wait_seconds: wait_seconds,
      sleeper: sleeper
    )
    loop_obj
  end

  def test_runs_agent_once_per_task_then_waits
    runs = { tasks: [], waits: [] }
    provider = scheduled_provider([%w[TASK-1 TASK-2], []])

    loop_that_stops_after_first_wait(provider: provider, runs: runs).run

    assert_equal %w[TASK-1 TASK-2], runs[:tasks]
    assert_equal [0.01], runs[:waits]
  end

  def test_waits_when_no_tasks
    runs = { tasks: [], waits: [] }
    provider = scheduled_provider([[], [], []])

    loop_that_stops_after_first_wait(provider: provider, runs: runs, wait_seconds: 0.5).run

    assert_empty runs[:tasks]
    assert_equal [0.5], runs[:waits]
  end

  def test_returns_number_of_runs
    runs = { tasks: [], waits: [] }
    provider = scheduled_provider([%w[A B C], []])

    result = loop_that_stops_after_first_wait(provider: provider, runs: runs).run

    assert_equal 3, result
    assert_equal %w[A B C], runs[:tasks]
  end

  def test_nil_tasks_means_retry_without_running
    # nil = бэклог не читается: агента не запускаем, ждём и пробуем снова.
    runs = { tasks: [], waits: [] }
    provider_calls = 0
    provider = lambda do
      provider_calls += 1
      provider_calls <= 2 ? nil : []
    end

    loop_obj = nil
    sleeper = lambda do |seconds|
      runs[:waits] << seconds
      loop_obj.stop if provider_calls >= 3
    end
    loop_obj = Letsdo::Loop.new(
      task_provider: provider,
      run_task: ->(task) { runs[:tasks] << task },
      wait_seconds: 0.01,
      sleeper: sleeper
    )

    loop_obj.run

    assert_empty runs[:tasks]
    assert_equal 3, provider_calls
    assert_equal 3, runs[:waits].length
  end
end