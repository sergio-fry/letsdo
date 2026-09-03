# frozen_string_literal: true

require_relative "test_helper"
require "stringio"
require "tempfile"

class AgentTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
    @streamer = Letsdo::OutputStreamer.new(stdout: @out, stderr: @err)
  end

  def make_agent(name:, root:, flags: [])
    Letsdo::Agent.new(name: name, root: root, flags: flags, streamer: @streamer, command: fake_pi)
  end

  def test_run_known_agent_returns_exit_code
    with_project("developer" => "You are a developer.") do |root|
      assert_equal 0, make_agent(name: "developer", root: root).run
    end
  end

  def test_run_known_agent_assembles_output
    with_project("developer" => "You are a developer.") do |root|
      make_agent(name: "developer", root: root).run

      assert_equal "Hello, world!\n", @out.string
    end
  end

  def test_run_known_agent_passes_prompt_to_pi
    with_project("developer" => "Developer prompt") do |root|
      Tempfile.create("fake_pi_argv") do |file|
        old = ENV["FAKE_PI_ARGV_FILE"]
        ENV["FAKE_PI_ARGV_FILE"] = file.path
        begin
          make_agent(name: "developer", root: root).run
        ensure
          ENV["FAKE_PI_ARGV_FILE"] = old
        end

        assert_includes File.read(file.path), "Developer prompt"
      end
    end
  end

  def test_run_known_agent_passes_flags_to_pi
    with_project("developer" => "You are a developer.") do |root|
      Tempfile.create("fake_pi_argv") do |file|
        old = ENV["FAKE_PI_ARGV_FILE"]
        ENV["FAKE_PI_ARGV_FILE"] = file.path
        begin
          make_agent(name: "developer", root: root, flags: ["--model", "m"]).run
        ensure
          ENV["FAKE_PI_ARGV_FILE"] = old
        end

        assert_includes File.read(file.path), "--mode|json|--model|m|"
      end
    end
  end

  def test_run_unknown_agent_raises
    with_project("developer" => "You are a developer.") do |root|
      assert_raises(Letsdo::UnknownAgentError) { make_agent(name: "nosuch", root: root).run }
    end
  end

  def test_run_unknown_agent_writes_nothing
    with_project("developer" => "You are a developer.") do |root|
      assert_raises(Letsdo::UnknownAgentError) { make_agent(name: "nosuch", root: root).run }

      assert_empty @out.string
      assert_empty @err.string
    end
  end
end