# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../lib/letsdo'

# Shared harness for the letsdo gem tests:
#
# - requires minitest/autorun (bundled with Ruby, no extra gems);
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
    Dir.mktmpdir('letsdo-project') do |dir|
      agents_dir = File.join(dir, 'agents')
      FileUtils.mkdir_p(agents_dir)
      prompts.each do |name, body|
        File.write(File.join(agents_dir, "#{name}.md"), body)
      end
      yield dir
    end
  end

  # Root of a temporary project without an agents/ directory
  def with_empty_project(&block)
    Dir.mktmpdir('letsdo-project', &block)
  end

  # Path to the fake pi.
  def fake_pi
    File.expand_path('fixtures/fake_pi', __dir__)
  end

  # Sets ENV keys for the duration of the block, then restores them.
  # A nil value deletes the key (same as an originally unset variable).
  def with_env(updates)
    previous = updates.keys.to_h { |key| [key, ENV.fetch(key, nil)] }
    updates.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end

  # Whether the monotonic deadline has passed (used by wait helpers).
  def overdue?(deadline)
    Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  end

  # Waits until the fake pi writes its readiness file. Returns the child
  # pid stored there. Hang-guarded by a deadline.
  def wait_for_ready_file(ready_file, timeout: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      return File.read(ready_file).to_i if File.exist?(ready_file)

      flunk "fake pi did not become ready within #{timeout}s" if overdue?(deadline)
      sleep 0.01
    end
  end
end

module Minitest
  class Test
    include LetsdoTestHelpers
  end
end
