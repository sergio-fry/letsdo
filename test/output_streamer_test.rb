# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

# Streamer tests share a clocked stdout/stderr pair. Each concern below
# is its own class so every class stays within the default length limits.
class OutputStreamerTest < Minitest::Test
  TIME_PREFIX = /\A\d{2}:\d{2}:\d{2} /

  def setup
    @out = StringIO.new
    @err = StringIO.new
    @now = Time.local(2026, 9, 3, 14, 5, 3) # 14:05:03
    @streamer = Letsdo::OutputStreamer.new(stdout: @out, stderr: @err, clock: -> { @now })
  end
end

# Assistant text goes to stdout with no time prefix; finish owns the
# trailing newline contract.
class OutputStreamerTextTest < OutputStreamerTest
  def test_text_delta_appends_to_stdout
    @streamer.text_delta('Hello, ')
    @streamer.text_delta('world!')

    assert_equal 'Hello, world!', @out.string
  end

  def test_text_delta_writes_immediately
    @streamer.text_delta('piece')

    assert_equal 'piece', @out.string
  end

  def test_text_delta_ignores_empty_and_nil
    @streamer.text_delta('')
    @streamer.text_delta(nil)

    assert_empty @out.string
  end

  def test_text_delta_has_no_time_prefix_in_stdout
    @streamer.text_delta('agent response')

    assert_equal 'agent response', @out.string
    assert_empty @err.string
  end

  def test_finish_adds_trailing_newline_when_missing
    @streamer.text_delta('response without newline')
    @streamer.finish

    assert_equal "response without newline\n", @out.string
  end

  def test_finish_does_not_add_second_newline
    @streamer.text_delta("reply\n")
    @streamer.finish

    assert_equal "reply\n", @out.string
  end

  def test_finish_is_noop_when_nothing_was_written
    @streamer.finish

    assert_empty @out.string
  end
end

# Tool start lines: name, args, truncation.
class OutputStreamerToolStartTest < OutputStreamerTest
  def test_tool_start_with_bash_command
    @streamer.tool_start('bash', args: { 'command' => 'ls -la' })

    assert_equal "14:05:03 ⚙ bash: ls -la\n", @err.string
    assert_empty @out.string
  end

  def test_tool_start_shows_read_path_and_line_range
    @streamer.tool_start('read', args: { 'path' => 'lib/letsdo.rb', 'offset' => 5, 'limit' => 3 })

    assert_equal "14:05:03 ⚙ read: lib/letsdo.rb:5-7\n", @err.string
  end

  def test_tool_start_without_args_prints_name_only
    @streamer.tool_start('ls', args: {})

    assert_equal "14:05:03 ⚙ ls\n", @err.string
  end

  def test_tool_start_with_nil_args_prints_name_only
    @streamer.tool_start('bash')

    assert_equal "14:05:03 ⚙ bash\n", @err.string
  end

  def test_tool_start_unknown_tool_shows_compact_json
    @streamer.tool_start('custom', args: { 'from' => 'a', 'to' => 'b' })

    assert_equal "14:05:03 ⚙ custom: {\"from\":\"a\",\"to\":\"b\"}\n", @err.string
  end

  def test_tool_start_truncates_long_args
    @streamer.tool_start('bash', args: { 'command' => ('a' * 500) })

    line = @err.string
    assert line.start_with?('14:05:03 ⚙ bash: ')
    assert line.end_with?("…\n")
    assert_operator line.length, :<, 350
  end
end

# Tool result lines: time prefix, errors, elapsed.
class OutputStreamerToolTest < OutputStreamerTest
  def test_every_action_line_has_hh_mm_ss_prefix
    emit_staggered_actions
    assert_action_line_prefixes(@err.string.lines)
  end

  def emit_staggered_actions
    @streamer.tool_start('bash', args: { 'command' => 'ls' })
    @now += 7
    @streamer.tool_start('read', args: { 'path' => 'a.rb' })
    @now += 3
    @streamer.tool_result('bash')
  end

  def assert_action_line_prefixes(lines)
    assert_equal 3, lines.length
    assert_timed_action_lines(lines)
  end

  def assert_timed_action_lines(lines)
    assert_match TIME_PREFIX, lines[0]
    assert_match TIME_PREFIX, lines[1]
    assert_match TIME_PREFIX, lines[2]
    assert_match(/\A14:05:03 ⚙/, lines[0])
    assert_match(/\A14:05:10 ⚙/, lines[1])
    assert_match(/\A14:05:13 ✓/, lines[2])
  end

  def test_tool_flow_prints_completion_with_elapsed
    @streamer.tool_start('bash', args: { 'command' => 'ls -la' })
    @now += 7
    @streamer.tool_result('bash')

    assert_equal "14:05:03 ⚙ bash: ls -la\n" \
                 "14:05:10 ✓ bash: done (7.0s)\n", @err.string
  end

  def test_tool_result_elapsed_rounds_seconds_over_ten
    @streamer.tool_start('bash')
    @now += 42
    @streamer.tool_result('bash')

    assert_includes @err.string, "14:05:45 ✓ bash: done (42s)\n"
  end

  def test_tool_result_error_is_marked
    @streamer.tool_result('bash', error: true)

    assert_equal "14:05:03 ✖ bash: error\n", @err.string
  end

  def test_tool_result_empty_still_prints_completion
    @streamer.tool_result('bash')
    @streamer.tool_result('bash')

    assert_equal "14:05:03 ✓ bash: done\n" \
                 "14:05:03 ✓ bash: done\n", @err.string
  end

  def test_tool_result_without_known_start_omits_elapsed
    @streamer.tool_result('bash')

    assert_equal "14:05:03 ✓ bash: done\n", @err.string
  end
end

# Tool result lines: the completion line only — no indented result body,
# no error-body marker, no truncation note.
class OutputStreamerResultShapeTest < OutputStreamerTest
  def test_tool_result_prints_only_the_completion_line
    @streamer.tool_result('bash')

    assert_equal "14:05:03 ✓ bash: done\n", @err.string
  end

  def test_tool_result_error_prints_only_the_completion_line
    @streamer.tool_start('bash')
    @streamer.tool_result('bash', error: true)

    assert_equal "14:05:03 ⚙ bash\n" \
                 "14:05:03 ✖ bash: error (0.0s)\n", @err.string
  end

  def test_no_indented_body_lines_for_error_results
    @streamer.tool_result('bash', error: true)

    refute_includes @err.string, '✖ Error:'
    refute_includes @err.string, '  '
  end

  def test_no_truncation_note_for_large_output
    @streamer.tool_start('bash', args: { 'command' => 'seq 1 200' })
    @streamer.tool_result('bash')

    refute_includes @err.string, 'line 1'
    refute_includes @err.string, 'output truncated'
  end
end

# TUI mode: everything goes to the injected log target (TASK-42).
class OutputStreamerLogTargetTest < OutputStreamerTest
  def test_log_target_receives_text_and_tool_lines_in_order
    log = Letsdo::Tui::LogBuffer.new
    stream_into(log)

    combined = log.lines.first.join("\n")
    assert_log_order(combined)
    assert_empty @out.string
    assert_empty @err.string
  end

  def stream_into(log)
    streamer = Letsdo::OutputStreamer.new(log: log, clock: -> { @now })
    streamer.text_delta('Hello ')
    streamer.tool_start('bash', args: { 'command' => 'echo hi' })
    streamer.tool_result('bash')
    streamer.text_delta('world')
    streamer.finish
  end

  def assert_log_order(combined)
    assert_includes combined, 'Hello '
    assert_includes combined, 'world'
    assert_includes combined, '14:05:03 ⚙ bash: echo hi'
    assert_includes combined, '14:05:03 ✓ bash: done'
    assert_match(/Hello .*world/m, combined)
  end

  def test_log_target_keeps_the_final_newline_contract
    log = Letsdo::Tui::LogBuffer.new
    streamer = Letsdo::OutputStreamer.new(log: log, clock: -> { @now })
    streamer.text_delta('no trailing newline')
    streamer.finish

    assert_equal ['no trailing newline'], log.lines.first
  end
end
