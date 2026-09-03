# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/letsdo"

# Shared harness for the letsdo gem tests:
#
# - requires minitest/autorun (bundled with Ruby, no external gems);
#   tests use only the simple assert/refute syntax — no DSL or
#   mock frameworks.
# - fixtures are created in temporary directories (Dir.mktmpdir) and
#   removed automatically after each test.
# - tests that run pi use the fake executable script
#   test/fixtures/fake_pi (see its header).

module LetsdoTestHelpers
  # Root of a temporary project: agents/ with prompts (name => contents).
  #
  # @param prompts [Hash{String=>String}] agent name → prompt text
  # @return [String] path to the temporary project root
  def with_project(prompts)
    Dir.mktmpdir("letsdo-project") do |dir|
      agents_dir = File.join(dir, "agents")
      FileUtils.mkdir_p(agents_dir)
      prompts.each do |name, body|
        File.write(File.join(agents_dir, "#{name}.md"), body)
      end
      yield dir
    end
  end

  # Root of a temporary project without an agents/ directory
  def with_empty_project
    Dir.mktmpdir("letsdo-project") { |dir| yield dir }
  end

  # Path to the fake pi.
  def fake_pi
    File.expand_path("fixtures/fake_pi", __dir__)
  end
end

class Minitest::Test
  include LetsdoTestHelpers
end