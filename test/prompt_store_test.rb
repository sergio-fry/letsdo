# frozen_string_literal: true

require_relative 'test_helper'

class PromptStoreTest < Minitest::Test
  def test_list_returns_sorted_agent_names
    with_project('zeta' => 'prompt', 'alpha' => 'prompt') do |root|
      assert_equal %w[alpha zeta], Letsdo::PromptStore.new(root: root).list
    end
  end

  def test_list_is_empty_when_no_agents_dir
    with_empty_project do |root|
      assert_empty Letsdo::PromptStore.new(root: root).list
    end
  end

  def test_read_returns_prompt_content
    with_project('developer' => 'You are a developer.') do |root|
      assert_equal 'You are a developer.', Letsdo::PromptStore.new(root: root).read('developer')
    end
  end

  def test_read_known_agent
    with_project('looptest' => 'You test the loop.') do |root|
      assert Letsdo::PromptStore.new(root: root).read('looptest').include?('loop')
    end
  end

  def test_read_returns_nil_for_missing_agent
    with_project('developer' => 'You are a developer.') do |root|
      assert_nil Letsdo::PromptStore.new(root: root).read('nosuch')
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
      expected = File.join(File.expand_path(root), 'agents', 'nosuch.md')
      assert_equal expected, store.agent_path('nosuch')
    end
  end

  def test_agent_path_works_without_agents_dir
    with_empty_project do |root|
      assert_match %r{/agents/nosuch\.md\z}, Letsdo::PromptStore.new(root: root).agent_path('nosuch')
    end
  end

  def test_create_agent_writes_exact_content
    with_empty_project do |root|
      assert Letsdo::PromptStore.new(root: root).create_agent('developer', 'You are a developer.')
      assert_equal 'You are a developer.', Letsdo::PromptStore.new(root: root).read('developer')
    end
  end

  def test_create_agent_writes_exactly_the_default_prompt
    with_empty_project do |root|
      assert Letsdo::PromptStore.new(root: root).create_agent('developer', Letsdo::DefaultPrompt::TEXT)
      assert_equal Letsdo::DefaultPrompt::TEXT, Letsdo::PromptStore.new(root: root).read('developer')
    end
  end

  def test_create_agent_creates_the_agents_dir
    with_empty_project do |root|
      refute File.directory?(File.join(root, 'agents'))
      assert Letsdo::PromptStore.new(root: root).create_agent('developer', 'x')
      assert_equal ['developer'], Letsdo::PromptStore.new(root: root).list
    end
  end

  def test_create_agent_refuses_an_existing_file_without_overwriting
    with_project('developer' => 'original') do |root|
      refute Letsdo::PromptStore.new(root: root).create_agent('developer', 'replacement')
      assert_equal 'original', Letsdo::PromptStore.new(root: root).read('developer')
    end
  end

  def test_create_agent_refuses_unsafe_names_and_writes_nothing
    ['a/b', 'a\\b', '../x', '.', '..'].each do |name|
      with_empty_project do |root|
        refute Letsdo::PromptStore.new(root: root).create_agent(name, 'x'), "expected #{name.inspect} to be refused"
        assert_empty Dir.glob(File.join(root, '**', '*.md')), "#{name.inspect} created a file"
      end
    end
  end

  def test_create_agent_never_writes_outside_agents
    with_empty_project do |root|
      refute Letsdo::PromptStore.new(root: root).create_agent('../escape', 'x')
      refute File.exist?(File.join(root, 'escape.md'))
    end
  end
end

class PromptStoreConfigTest < Minitest::Test
  def test_config_returns_empty_hash_when_file_missing
    with_empty_project do |root|
      assert_equal({}, Letsdo::PromptStore.new(root: root).config('nosuch'))
    end
  end

  def test_config_returns_empty_hash_when_no_front_matter
    with_project('developer' => 'Prompt without config.') do |root|
      assert_equal({}, Letsdo::PromptStore.new(root: root).config('developer'))
    end
  end

  def test_config_parses_model_from_front_matter
    content = "---\nmodel: gpt-4o\n---\n# Developer\nPrompt text.\n"
    with_project('developer' => content) do |root|
      cfg = Letsdo::PromptStore.new(root: root).config('developer')
      assert_equal 'gpt-4o', cfg[:model]
    end
  end

  def test_config_ignores_invalid_front_matter
    content = "---\n: invalid: yaml: [unclosed\n---\nPrompt.\n"
    with_project('developer' => content) do |root|
      assert_equal({}, Letsdo::PromptStore.new(root: root).config('developer'))
    end
  end
end
