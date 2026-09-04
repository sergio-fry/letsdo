# frozen_string_literal: true

require_relative 'test_helper'

class PromptStoreTest < Minitest::Test
  def test_list_returns_sorted_agent_names
    with_project('zeta' => 'prompt', 'alpha' => 'prompt') do |root|
      store = Letsdo::PromptStore.new(root: root)

      assert_equal %w[alpha zeta], store.list
    end
  end

  def test_list_is_empty_when_no_agents_dir
    with_empty_project do |root|
      assert_empty Letsdo::PromptStore.new(root: root).list
    end
  end

  def test_read_returns_prompt_content
    with_project('developer' => 'You are a developer.') do |root|
      store = Letsdo::PromptStore.new(root: root)

      assert_equal 'You are a developer.', store.read('developer')
    end
  end

  def test_read_known_agent
    with_project('looptest' => 'You test the loop.') do |root|
      store = Letsdo::PromptStore.new(root: root)

      assert store.read('looptest').include?('loop')
    end
  end

  def test_read_returns_nil_for_missing_agent
    with_project('developer' => 'You are a developer.') do |root|
      store = Letsdo::PromptStore.new(root: root)

      assert_nil store.read('nosuch')
    end
  end

  def test_read_returns_nil_when_no_agents_dir
    with_empty_project do |root|
      assert_nil Letsdo::PromptStore.new(root: root).read('x')
    end
  end

  def test_agent_path_is_absolute_and_predictable
    with_empty_project do |root|
      store = Letsdo::PromptStore.new(root: root)

      assert_equal File.join(File.expand_path(root), 'agents', 'nosuch.md'), store.agent_path('nosuch')
    end
  end

  def test_agent_path_works_without_agents_dir
    with_empty_project do |root|
      assert_match %r{/agents/nosuch\.md\z}, Letsdo::PromptStore.new(root: root).agent_path('nosuch')
    end
  end
end
