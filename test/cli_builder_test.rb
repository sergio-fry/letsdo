# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'tempfile'
require_relative 'helpers/fake_backend'

# Letsdo::CLI::Builder (TASK-54): the wiring half of the CLI. Parsing and
# usage stay in Letsdo::CLI; the builder owns component assembly and the
# plain-vs-TUI decision (stdout/stdin TTY + TERM).
class CliBuilderTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  def stop_on_first_wait
    ->(_seconds) { throw Letsdo::AgentLoop::STOP }
  end

  def builder(root, stdout: @out, stdin: StringIO.new, env: {})
    Letsdo::CLI::Builder.new(env: env.merge('LETSDO_ROOT' => root), stdout: stdout,
                             stderr: @err, stdin: stdin, sleeper: stop_on_first_wait)
  end

  def fake_backlog_env(scenario: 'empty')
    {
      'LETSDO_BACKLOG_COMMAND' => File.expand_path('fixtures/fake_backlog', __dir__),
      'FAKE_BACKLOG_SCENARIO' => scenario,
      'LETSDO_PI_COMMAND' => File.expand_path('fixtures/fake_pi', __dir__)
    }
  end

  # TUI engagement belongs to the builder (TASK-54): stdout TTY && stdin TTY
  # && TERM != dumb choose the TUI path; anything less falls back to plain.
  def tui?(root, stdout:, stdin:, term:)
    builder(root, stdout: stdout, stdin: stdin, env: fake_backlog_env.merge('TERM' => term))
      .send(:tui?)
  end

  def test_engages_with_stdout_stdin_tty_and_real_term
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      assert tui?(root, stdout: FakeTtyOut.new, stdin: FakeTtyIn.new('q'), term: 'xterm')
    end
  end

  def test_not_engaged_when_stdout_is_not_a_tty
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      refute tui?(root, stdout: StringIO.new, stdin: FakeTtyIn.new('q'), term: 'xterm')
    end
  end

  def test_not_engaged_when_stdin_is_not_a_tty
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      refute tui?(root, stdout: FakeTtyOut.new, stdin: StringIO.new, term: 'xterm')
    end
  end

  def test_not_engaged_when_term_is_dumb
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      refute tui?(root, stdout: FakeTtyOut.new, stdin: FakeTtyIn.new('q'), term: 'dumb')
    end
  end

  def test_plain_run_assembles_the_loop_and_exits_cleanly
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      code = builder(root, env: fake_backlog_env).run('developer')

      assert_equal 0, code
      assert_includes @err.string, 'letsdo: no open tasks for developer'
    end
  end

  def tui_builder(root, stdout:, stdin:, env:)
    Letsdo::CLI::Builder.new(env: env.merge('LETSDO_ROOT' => root), stdout: stdout,
                             stderr: @err, stdin: stdin, sleeper: stop_on_first_wait)
  end

  def test_tui_run_engages_through_the_builder
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      tty_out = FakeTtyOut.new
      env = fake_backlog_env.merge('FAKE_BACKLOG_COUNT' => '1', 'TERM' => 'xterm')
      code = tui_builder(root, stdout: tty_out, stdin: FakeTtyIn.new('q'), env: env)
             .run('developer')

      assert_equal 0, code
      assert_includes tty_out.string, "\e[?1049h"
      assert_includes tty_out.string, "\e[?1049l"
      assert_empty @err.string
    end
  end

  def test_run_notifies_once_for_a_missing_prompt
    with_project({}) do |root|
      code = builder(root, env: fake_backlog_env).run('ghost')

      assert_equal 0, code
      assert_equal 1, @err.string.scan('letsdo: no prompt for ghost at ').size
    end
  end
end

# Provider selection (TASK-58): the builder resolves LETSDO_PROVIDER through
# the provider registry and fails fast on an unknown name.
class CliBuilderProviderTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  def stop_on_first_wait
    ->(_seconds) { throw Letsdo::AgentLoop::STOP }
  end

  def fake_backlog_env
    {
      'LETSDO_BACKLOG_COMMAND' => File.expand_path('fixtures/fake_backlog', __dir__),
      'FAKE_BACKLOG_SCENARIO' => 'empty',
      'LETSDO_PI_COMMAND' => File.expand_path('fixtures/fake_pi', __dir__)
    }
  end

  def test_unknown_provider_fails_fast_with_error_and_exit_one
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      env = fake_backlog_env.merge('LETSDO_ROOT' => root, 'LETSDO_PROVIDER' => 'jira')
      code = builder_for(env).run('developer')

      assert_equal 1, code
      assert_includes @err.string, 'letsdo: unknown task provider: jira'
    end
  end

  def test_provider_registry_is_injectable
    state = { calls: 0, built_with: nil }
    registry = custom_registry(state)
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      env = { 'LETSDO_ROOT' => root, 'LETSDO_PROVIDER' => 'custom' }
      code = builder_for(env, registry: registry).run('developer')

      assert_equal 0, code
      assert_equal 1, state[:calls]
      assert_equal ['@developer', 'backlog', root], state[:built_with][0, 3]
      assert_kind_of Hash, state[:built_with][3]
    end
  end

  def custom_registry(state)
    {
      'custom' => lambda do |handle:, command:, cwd:, env:|
        state[:built_with] = [handle, command, cwd, env]
        fake_provider { state[:calls] += 1 }
      end
    }
  end

  private

  def builder_for(env, registry: nil, backend_registry: nil)
    Letsdo::CLI::Builder.new(env: env, stdout: @out, stderr: @err, stdin: StringIO.new,
                             sleeper: stop_on_first_wait, provider_registry: registry,
                             backend_registry: backend_registry)
  end

  def fake_provider(&call)
    # call responds with an empty batch: an empty array pauses the loop.
    Object.new.tap do |provider|
      provider.define_singleton_method(:call) do
        call.call
        []
      end
    end
  end
end

# Backend selection (TASK-60): the builder resolves LETSDO_BACKEND through
# the backend registry and fails fast on an unknown name; the registry is
# injectable so an in-process fake backend can be switched in for tests.
class CliBuilderBackendTest < Minitest::Test
  def setup
    @out = StringIO.new
    @err = StringIO.new
  end

  def stop_on_first_wait
    ->(_seconds) { throw Letsdo::AgentLoop::STOP }
  end

  def fake_backlog_env
    {
      'LETSDO_BACKLOG_COMMAND' => File.expand_path('fixtures/fake_backlog', __dir__),
      'FAKE_BACKLOG_SCENARIO' => 'empty',
      'LETSDO_PI_COMMAND' => File.expand_path('fixtures/fake_pi', __dir__)
    }
  end

  def open_backlog_env(count:, done_file:)
    {
      'LETSDO_BACKLOG_COMMAND' => File.expand_path('fixtures/fake_backlog', __dir__),
      'FAKE_BACKLOG_SCENARIO' => 'open',
      'FAKE_BACKLOG_COUNT' => count.to_s,
      'FAKE_BACKLOG_DONE_FILE' => done_file,
      'LETSDO_PI_COMMAND' => File.expand_path('fixtures/fake_pi', __dir__)
    }
  end

  def test_unknown_backend_fails_fast_with_error_and_exit_one
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      env = fake_backlog_env.merge('LETSDO_ROOT' => root, 'LETSDO_BACKEND' => 'claude')
      code = builder_for(env).run('developer')

      assert_equal 1, code
      assert_includes @err.string, 'letsdo: unknown AI backend: claude'
    end
  end

  def test_backend_registry_is_injectable_with_the_fake_backend
    state = { built: 0, run: 0 }

    code = run_with_backend(custom_backend_registry(state), backend: 'fake')

    assert_equal 0, code
    assert_equal 1, state[:built]
    assert_equal 1, state[:run]
    assert_includes @err.string, 'letsdo: running developer for TASK-1'
  end

  def test_no_letsdo_backend_uses_the_pi_default_path
    code = run_with_backend(nil, backend: 'pi')

    assert_equal 0, code
    assert_includes @err.string, 'letsdo: running developer for TASK-1'
    # The default pi backend runs via the fake pi (LETSDO_PI_COMMAND);
    # its output goes to the streamer stdout.
    assert_equal "Hello, world!\n", @out.string
  end

  private

  # Runs one open task through the (default or injected) backend registry.
  def run_with_backend(registry, backend:)
    done_file = unique_done_file
    with_project({ 'developer' => 'You are a developer.' }) do |root|
      env = open_backlog_env(count: 1, done_file: done_file)
            .merge('LETSDO_ROOT' => root, 'LETSDO_BACKEND' => backend)
      builder_for(env, backend_registry: registry).run('developer')
    end
  end

  def unique_done_file
    File.join(Dir.mktmpdir('letsdo-done'), 'marker')
  end

  def builder_for(env, registry: nil, backend_registry: nil)
    Letsdo::CLI::Builder.new(env: env, stdout: @out, stderr: @err, stdin: StringIO.new,
                             sleeper: stop_on_first_wait, provider_registry: registry,
                             backend_registry: backend_registry)
  end

  def custom_backend_registry(state)
    { 'fake' => ->(_) { build_fake_factory(state) } }
  end

  def build_fake_factory(state)
    lambda do |prompt:, streamer:, **_|
      state[:built] += 1
      Letsdo::Backends::Fake.new(prompt: prompt, streamer: streamer).tap do |fb|
        fb.define_singleton_method(:run) do
          state[:run] += 1
          0
        end
      end
    end
  end
end
