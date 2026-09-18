# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# Letsdo::AgentIdentity (TASK-85): the identity block letsdo injects into
# every agent prompt. Pure string composition — no files, no backends.
# Since TASK-96 the block presents the bare tracker assignee and marks the
# '@' prefix as prose notation only.
class AgentIdentityTest < Minitest::Test
  def test_preamble_names_the_agent_and_its_bare_assignee
    text = Letsdo::AgentIdentity.preamble(name: 'developer', handle: 'developer')

    assert_includes text, 'You are the agent `developer`'
    assert_includes text, 'backlog assignee is `developer`'
    assert_includes text, "'@developer') is prose notation only"
  end

  def test_preamble_ends_with_a_blank_line_separator
    text = Letsdo::AgentIdentity.preamble(name: 'developer', handle: 'developer')

    assert text.end_with?("\n\n"), 'identity block must be separated from the prompt'
  end

  def test_inject_prepends_the_identity_and_keeps_the_prompt
    prompt = "# Task agent\n\nDo the work.\n"
    text = Letsdo::AgentIdentity.inject(prompt, name: 'dev', handle: 'dev')

    assert text.start_with?('# Your identity')
    assert text.end_with?(prompt)
    assert_operator text.index('You are the agent `dev`'), :<, text.index('# Task agent')
  end
end

# Agent-level injection (TASK-85): every run leads with the identity block,
# whatever prompt was loaded and whichever handle the launcher resolved.
class AgentIdentityInjectionTest < Minitest::Test
  def setup
    @streamer = Letsdo::OutputStreamer.new(stdout: StringIO.new, stderr: StringIO.new)
  end

  def test_identity_leads_a_custom_prompt
    prompt = injected_prompt(name: 'developer', prompts: { 'developer' => 'Developer prompt' })

    assert prompt.start_with?('# Your identity')
    assert_includes prompt, 'You are the agent `developer`'
    assert_includes prompt, 'backlog assignee is `developer`'
    assert_includes prompt, 'Developer prompt'
  end

  def test_identity_is_injected_into_the_built_in_default_prompt
    prompt = injected_prompt(name: 'nosuch', prompts: {})

    assert prompt.start_with?('# Your identity')
    assert_includes prompt, Letsdo::DefaultPrompt::TEXT
  end

  def test_launcher_supplied_handle_wins
    prompt = injected_prompt(name: 'developer', prompts: { 'developer' => 'Developer prompt' },
                             handle: 'someone')

    assert_includes prompt, 'backlog assignee is `someone`'
    refute_includes prompt, 'backlog assignee is `developer`'
  end

  private

  # Runs one agent with a capturing backend and returns the prompt it got.
  def injected_prompt(name:, prompts:, handle: nil)
    seen = {}
    factory = lambda do |**args|
      seen[:prompt] = args[:prompt]
      Object.new.tap { |backend| backend.define_singleton_method(:run) { 0 } }
    end
    with_project(prompts) do |root|
      Letsdo::Agent.new(name: name, root: root, backend_factory: factory,
                        streamer: @streamer, handle: handle).run
    end
    seen[:prompt]
  end
end
