# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

class LoopTest < Minitest::Test
  # A task provider returning tasks on a schedule:
  #   schedule = [[...], [...]] — which tasks to return on each call.
  def scheduled_provider(schedule)
    index = 0
    lambda do
      result = index < schedule.length ? schedule[index] : []
      index += 1
      result
    end
  end

  # Creates a loop that stops right after the first wait.
  def loop_that_stops_after_first_wait(provider:, runs:, wait_seconds: 0.01)
    sleeper = lambda do |seconds|
      runs[:waits] << seconds
      @loop_under_test.stop
    end
    @loop_under_test = Letsdo::Loop.new(
      task_provider: provider,
      run_task: ->(task) { runs[:tasks] << task },
      wait_seconds: wait_seconds,
      sleeper: sleeper
    )
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
    # nil = the backlog is unreadable: we do not run the agent, wait and retry.
    runs = { tasks: [], waits: [], provider_calls: 0 }
    provider = lambda do
      runs[:provider_calls] += 1
      runs[:provider_calls] <= 2 ? nil : []
    end
    stop_when = -> { runs[:provider_calls] >= 3 }
    run_loop_until(provider, stop_when, runs)

    assert_empty runs[:tasks]
    assert_equal 3, runs[:provider_calls]
    assert_equal 3, runs[:waits].length
  end

  # Runs a loop whose sleeper stops it once stop_when becomes truthy;
  # agent runs and wait intervals are recorded in runs.
  def run_loop_until(provider, stop_when, runs, wait_seconds: 0.01)
    @loop_under_test = Letsdo::Loop.new(
      task_provider: provider,
      run_task: ->(task) { runs[:tasks] << task },
      wait_seconds: wait_seconds,
      sleeper: lambda do |seconds|
        runs[:waits] << seconds
        @loop_under_test.stop if stop_when.call
      end
    )
    @loop_under_test.run
  end
end
