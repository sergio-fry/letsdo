# frozen_string_literal: true

require_relative '../test_helper'
require 'tempfile'

module ProvidersBacklogTestHelpers
  # Runs the provider with FAKE_BACKLOG_SCENARIO/COUNT set for the duration.
  def call_provider(scenario: nil, count: nil)
    command = File.expand_path('../fixtures/fake_backlog', __dir__)
    vars = {}
    vars['FAKE_BACKLOG_SCENARIO'] = scenario if scenario
    vars['FAKE_BACKLOG_COUNT'] = count.to_s if count
    with_env(vars) { Letsdo::Providers::Backlog.new(handle: '@developer', command: command, cwd: Dir.pwd).call }
  end

  # Sets environment variables for the duration of the block and removes
  # them after (restores previous values).
  def with_env(vars)
    old = {}
    vars.each do |key, value|
      old[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    old.each { |key, value| ENV[key] = value }
  end
end

class ProvidersBacklogTest < Minitest::Test
  include ProvidersBacklogTestHelpers

  def test_open_tasks_are_returned_with_ids
    tasks = call_provider(scenario: 'open', count: 3)

    assert_equal 3, tasks.length
    assert_equal(%w[TASK-1 TASK-2 TASK-3], tasks.map(&:id))
    tasks.each { |task| assert_instance_of(Letsdo::Providers::Task, task) }
  end

  def test_no_tasks_returns_empty_array
    assert_equal [], call_provider(scenario: 'empty')
  end

  def test_failed_backlog_returns_nil
    assert_nil call_provider(scenario: 'fail')
  end

  def test_non_json_output_returns_nil
    assert_nil call_provider(scenario: 'malformed')
  end

  def test_missing_command_returns_nil
    provider = Letsdo::Providers::Backlog.new(handle: '@developer',
                                              command: '/nonexistent/backlog', cwd: Dir.pwd)

    assert_nil provider.call
  end

  def test_assignee_and_flags_in_command_line
    command = File.expand_path('../fixtures/fake_backlog', __dir__)
    Tempfile.create('fake_backlog_argv') do |file|
      with_env('FAKE_BACKLOG_ARGV_FILE' => file.path) do
        Letsdo::Providers::Backlog.new(handle: '@developer', command: command, cwd: Dir.pwd).call
      end
      assert_equal "task|list|--assignee|@developer|--exclude-status|Done|--json\n",
                   File.read(file.path)
    end
  end
end

class ProvidersTaskTest < Minitest::Test
  def test_to_s_returns_id
    task = Letsdo::Providers::Task.new(id: 'TASK-42', title: 'Hello')
    assert_equal 'TASK-42', task.to_s
  end

  def test_to_s_falls_back_to_title_when_id_empty
    task = Letsdo::Providers::Task.new(id: '', title: 'Hello World')
    assert_equal 'Hello World', task.to_s
  end

  def test_to_s_falls_back_to_title_when_id_nil
    task = Letsdo::Providers::Task.new(id: nil, title: 'Hello World')
    assert_equal 'Hello World', task.to_s
  end

  def test_assignees_coerced_to_array
    task = Letsdo::Providers::Task.new(id: 'TASK-1', assignees: nil)
    assert_equal [], task.assignees
  end

  def test_task_is_frozen
    task = Letsdo::Providers::Task.new(id: 'TASK-1')
    assert task.frozen?
  end
end
