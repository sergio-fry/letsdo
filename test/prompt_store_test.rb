# frozen_string_literal: true

require_relative "test_helper"

class PromptStoreTest < Minitest::Test
  def test_list_returns_sorted_agent_names
    with_project("zeta" => "prompt", "alpha" => "prompt") do |root|
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
    with_project("developer" => "You are a developer.") do |root|
      store = Letsdo::PromptStore.new(root: root)

      assert_equal "You are a developer.", store.read("developer")
    end
  end

  def test_read_known_agent
    with_project("looptest" => "You test the loop.") do |root|
      store = Letsdo::PromptStore.new(root: root)

      assert store.read("looptest").include?("loop")
    end
  end

  def test_read_unknown_agent_raises
    with_project("developer" => "You are a developer.") do |root|
      store = Letsdo::PromptStore.new(root: root)

      error = assert_raises(Letsdo::UnknownAgentError) { store.read("nosuch") }
      assert_equal "nosuch", error.name
      assert_match(/Unknown agent: nosuch/, error.message)
    end
  end

  def test_read_unknown_agent_raises_even_when_no_agents_dir
    with_empty_project do |root|
      error = assert_raises(Letsdo::UnknownAgentError) { Letsdo::PromptStore.new(root: root).read("x") }
      refute_nil error
    end
  end

  def test_unknown_agent_error_is_a_letsdo_error
    with_empty_project do |root|
      error = assert_raises(Letsdo::UnknownAgentError) { Letsdo::PromptStore.new(root: root).read("x") }
      assert_kind_of Letsdo::Error, error
      assert_kind_of StandardError, error
    end
  end
end