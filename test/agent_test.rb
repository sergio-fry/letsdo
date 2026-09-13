# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'tempfile'

class AgentTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
    @streamer = Letsdo::OutputStreamer.new(stdout: @out, stderr: @err)
  end

  def make_agent(name:, root:, flags: [])
    pi_backend_factory = lambda do |prompt:, streamer:, model: nil|
      Letsdo::Backends::Pi.new(prompt: prompt, streamer: streamer, flags: flags, command: fake_pi, model: model)
    end
    Letsdo::Agent.new(name: name, root: root, backend_factory: pi_backend_factory, streamer: @streamer)
  end

  def test_run_known_agent_returns_exit_code
    with_project('developer' => 'You are a developer.') do |root|
      assert_equal 0, make_agent(name: 'developer', root: root).run
    end
  end

  def test_run_known_agent_assembles_output
    with_project('developer' => 'You are a developer.') do |root|
      make_agent(name: 'developer', root: root).run

      assert_equal "Hello, world!\n", @out.string
    end
  end

  # Runs the agent with FAKE_PI_ARGV_FILE pointing at a temp file and
  # returns the argv the fake pi recorded.
  def captured_argv(agent)
    Tempfile.create('fake_pi_argv') do |file|
      old = ENV['FAKE_PI_ARGV_FILE']
      ENV['FAKE_PI_ARGV_FILE'] = file.path
      begin
        agent.run
      ensure
        ENV['FAKE_PI_ARGV_FILE'] = old
      end
      File.read(file.path)
    end
  end

  def test_run_known_agent_passes_prompt_to_pi
    with_project('developer' => 'Developer prompt') do |root|
      argv = captured_argv(make_agent(name: 'developer', root: root))

      assert_includes argv, 'Developer prompt'
    end
  end

  def test_run_known_agent_passes_flags_to_pi
    with_project('developer' => 'You are a developer.') do |root|
      argv = captured_argv(make_agent(name: 'developer', root: root, flags: ['--model', 'm']))

      assert_includes argv, '--mode|json|--model|m|'
    end
  end

  def test_run_unknown_agent_uses_default_prompt
    with_project('developer' => 'You are a developer.') do |root|
      argv = captured_argv(make_agent(name: 'nosuch', root: root))

      assert_includes argv.split('|').last, Letsdo::DefaultPrompt::TEXT
    end
  end

  # Identity injection (TASK-85) is covered in agent_identity_test.rb; the
  # default-prompt fallback here only needs to prove the text still arrives.
  def test_run_unknown_agent_streams_output_like_a_known_one
    with_project('developer' => 'You are a developer.') do |root|
      make_agent(name: 'nosuch', root: root).run

      assert_equal "Hello, world!\n", @out.string
    end
  end

  def test_default_prompt_constant_is_frozen
    assert_predicate Letsdo::DefaultPrompt::TEXT, :frozen?
  end

  def test_run_agent_applies_model_from_front_matter
    content = <<~MD
      ---
      model: my-model
      ---
      Developer prompt.
    MD
    with_project('developer' => content) do |root|
      argv = captured_argv(make_agent(name: 'developer', root: root))

      assert_includes argv, '--model|my-model|'
    end
  end

  def test_agent_exposes_backend
    with_project('developer' => 'You are a developer.') do |root|
      agent = make_agent(name: 'developer', root: root)
      agent.run

      refute_nil agent.backend
    end
  end

  def test_run_agent_does_not_override_cli_model_flag
    content = "---\nmodel: file-model\n---\nDeveloper prompt.\n"
    with_project('developer' => content) do |root|
      argv = captured_argv(make_agent(name: 'developer', root: root, flags: ['--model', 'cli-model']))
      assert_includes argv, '--model|cli-model|'
      refute_includes argv, 'file-model'
    end
  end
end
