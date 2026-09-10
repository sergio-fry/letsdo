# frozen_string_literal: true

require 'English'
require_relative 'test_helper'
require 'rbconfig'

# Input decodes raw key bytes from an injected pipe — no real TTY
# anywhere (tty-reader's mode helpers no-op on non-tty inputs).
# A pipe (not StringIO) is required: tty-reader calls wait_readable
# for multi-byte sequences, and StringIO does not implement it.
class TuiInputTest < Minitest::Test
  def test_decodes_arrow_keys
    assert_equal :up, input_for("\e[A").next_key
    assert_equal :down, input_for("\e[B").next_key
  end

  def test_decodes_alternate_arrow_sequences
    assert_equal :up, input_for("\eOA").next_key
    assert_equal :down, input_for("\eOB").next_key
  end

  def test_decodes_page_keys
    assert_equal :page_up, input_for("\e[5~").next_key
    assert_equal :page_down, input_for("\e[6~").next_key
  end

  def test_decodes_home_and_end
    assert_equal :home, input_for("\e[H").next_key
    assert_equal :end, input_for("\e[F").next_key
    assert_equal :home, input_for("\e[1~").next_key
    assert_equal :end, input_for("\e[4~").next_key
  end

  def test_decodes_action_keys
    assert_equal :p, input_for('p').next_key
    assert_equal :r, input_for('r').next_key
    assert_equal :q, input_for('q').next_key
  end

  def test_decodes_ctrl_c_as_a_key
    assert_equal :ctrl_c, input_for("\u0003").next_key
  end

  def test_returns_nil_when_input_is_exhausted
    input = input_for('q')

    assert_equal :q, input.next_key
    assert_nil input.next_key
  end

  def test_unknown_keys_are_ignored
    assert_nil input_for('x').next_key
    assert_nil input_for("\t").next_key
  end

  def test_key_sequence_is_consumed_one_at_a_time
    input = input_for("\e[Ap")

    assert_equal :up, input.next_key
    assert_equal :p, input.next_key
  end

  # Boots a fresh interpreter with only lib/ on the load path and returns
  # its combined output. CLI does not preload stringio; Input must require
  # it itself. A same-process test cannot catch that (other files load
  # StringIO), so the check runs in a subprocess.
  def ruby_subprocess_output(code)
    lib = File.expand_path('../lib', __dir__)
    IO.popen(
      [RbConfig.ruby, '-I', lib, '-e', code],
      err: %i[child out],
      &:read
    )
  end

  def test_initializes_without_the_test_suite_preloading_stringio
    output = ruby_subprocess_output(<<~'RUBY')
      abort "preloaded" if defined?(StringIO)
      require "letsdo/tui/input"
      r, w = IO.pipe
      w.close
      Letsdo::Tui::Input.new(stdin: r, poll_timeout: 0)
      print "ok"
    RUBY

    assert_equal 0, $CHILD_STATUS.exitstatus, output
    assert_equal 'ok', output
  end
end
