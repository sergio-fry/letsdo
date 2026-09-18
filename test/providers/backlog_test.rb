# frozen_string_literal: true

require_relative '../test_helper'
require 'tempfile'

module ProvidersBacklogTestHelpers
  # Calls the provider with FAKE_BACKLOG_SCENARIO/COUNT set for the
  # duration. The default handle is the canonical bare name (TASK-96).
  def call_provider(scenario: nil, count: nil, handle: 'developer')
    vars = {}
    vars['FAKE_BACKLOG_SCENARIO'] = scenario if scenario
    vars['FAKE_BACKLOG_COUNT'] = count.to_s if count
    with_env(vars) { build_provider(handle: handle).call }
  end

  # Builds (not calls) a provider, so tests can inspect #assignee_variants
  # and call #call themselves.
  def build_provider(handle: 'developer')
    command = File.expand_path('../fixtures/fake_backlog', __dir__)
    Letsdo::Providers::Backlog.new(handle: handle, command: command, cwd: Dir.pwd)
  end

  # Sets environment variables for the duration of the block and removes
  # them after (restores previous values).
  def with_env(vars)
    old = {}
    vars.each do |key, value|
      old[key] = ENV[key]
      ENV[key] = value
    end
    begin
      yield
    ensure
      old.each { |key, value| ENV[key] = value }
    end
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

  # The real CLI returns extra keys (reporter, parentTaskId, createdAt,
  # updatedAt); the adapter must project them away instead of splatting
  # them into Task.new (TASK-91) while keeping the fields selection needs
  # (TASK-95).
  def test_full_real_schema_is_normalized
    task = call_provider(scenario: 'open', count: 1).first

    assert_equal 'TASK-1', task.id
    assert_equal 'Alpha', task.title
    assert_equal 'To Do', task.status
    assert_nil task.priority
    assert_equal ['developer'], task.assignees
  end

  def test_selection_fields_are_normalized
    task = call_provider(scenario: 'open', count: 1).first

    assert_equal 1001, task.ordinal
    assert_equal 'task', task.type
    assert_equal [], task.labels
    assert_nil task.milestone
  end

  def test_unknown_schema_keys_are_not_exposed
    task = call_provider(scenario: 'open', count: 1).first

    refute task.respond_to?(:reporter)
    refute task.respond_to?(:parentTaskId)
    refute task.respond_to?(:createdAt)
  end

  def test_missing_optional_fields_parse_and_absent_id_falls_back_to_title
    tasks = call_provider(scenario: 'sparse')

    assert_equal ['TASK-1', nil], tasks.map(&:id)
    assert_equal 'TASK-1', tasks.first.to_s
    assert_equal 'No id here', tasks.last.to_s
  end

  def test_non_object_task_entry_returns_nil
    assert_nil call_provider(scenario: 'weird')
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
    provider = Letsdo::Providers::Backlog.new(handle: 'developer',
                                              command: '/nonexistent/backlog', cwd: Dir.pwd)

    assert_nil provider.call
  end

  # TASK-96: the assignee filter runs in Ruby, not on the CLI line — the
  # CLI's --assignee is an exact-string match, so notation deviations
  # ('@developer' vs 'developer') would silently starve the loop.
  def test_command_line_has_no_assignee_flag
    Tempfile.create('fake_backlog_argv') do |file|
      with_env('FAKE_BACKLOG_ARGV_FILE' => file.path) do
        build_provider(handle: 'developer').call
      end
      assert_equal "task|list|--exclude-status|Done|--ready|--sort|priority|--json\n",
                   File.read(file.path)
    end
  end

  # The canonical default: bare-name tasks are picked up as-is, the legacy
  # '@'-prefixed and case variants still match, other agents' tasks never.
  def test_bare_handle_matches_all_notations_and_filters_other_agents
    provider = build_provider
    tasks = with_env('FAKE_BACKLOG_SCENARIO' => 'assignees') { provider.call }

    assert_equal %w[TASK-1 TASK-2 TASK-3], tasks.map(&:id)
    assert_equal %w[@developer Developer], provider.assignee_variants
  end

  # A legacy '@'-prefixed AGENT_ASSIGNEE_HANDLE override keeps matching the
  # same tasks (escape hatch), recording the bare/case values as variants.
  def test_at_prefixed_handle_still_matches_bare_tasks
    provider = build_provider(handle: '@developer')
    tasks = with_env('FAKE_BACKLOG_SCENARIO' => 'assignees') { provider.call }

    assert_equal %w[TASK-1 TASK-2 TASK-3], tasks.map(&:id)
    assert_equal %w[Developer developer], provider.assignee_variants
  end

  def test_variants_are_empty_for_exact_batches_and_reset_per_call
    provider = build_provider
    with_env('FAKE_BACKLOG_SCENARIO' => 'assignees') { provider.call }
    refute_empty provider.assignee_variants

    with_env('FAKE_BACKLOG_SCENARIO' => 'open') { provider.call }
    assert_empty provider.assignee_variants
  end

  # handle: nil is the doctor path: no filtering, no variants recorded.
  def test_nil_handle_keeps_every_task
    provider = build_provider(handle: nil)
    tasks = with_env('FAKE_BACKLOG_SCENARIO' => 'assignees') { provider.call }

    assert_equal %w[TASK-1 TASK-2 TASK-3 TASK-4], tasks.map(&:id)
    assert_empty provider.assignee_variants
  end

  # --ready turns the fake CLI into the readiness filter: blocked tasks
  # (unfinished dependencies) are dropped before the adapter sees them, so
  # the loop is never offered them.
  def test_blocked_tasks_are_not_offered
    tasks = call_provider(scenario: 'blocked')

    assert_equal %w[TASK-1 TASK-3], tasks.map(&:id)
  end

  # Equal priority is the common case; the batch must still be a total order:
  # In Progress first, then High > Medium > Low, then ordinal, then id.
  def test_batch_order_is_deterministic_with_equal_priority_tie_break
    tasks = call_provider(scenario: 'order')

    assert_equal %w[TASK-E TASK-C TASK-D TASK-B TASK-A TASK-F], tasks.map(&:id)
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

  def test_labels_coerced_to_array
    task = Letsdo::Providers::Task.new(id: 'TASK-1', labels: nil)
    assert_equal [], task.labels
  end

  def test_selection_fields_default_to_empty
    task = Letsdo::Providers::Task.new(id: 'TASK-1')

    assert_nil task.ordinal
    assert_nil task.type
    assert_nil task.milestone
    assert_equal [], task.labels
  end

  def test_task_is_frozen
    task = Letsdo::Providers::Task.new(id: 'TASK-1')
    assert task.frozen?
  end

  def test_unknown_keyword_is_a_programming_error
    error = assert_raises(ArgumentError) do
      Letsdo::Providers::Task.new(id: 'TASK-1', reporter: '@human')
    end

    assert_includes error.message, 'reporter'
  end
end
