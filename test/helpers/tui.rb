# frozen_string_literal: true

# Shared TUI test patterns (TASK-55): an input sourced from scripted key
# bytes, an injected terminal size provider, and raw-mode lifecycle fakes.
module TuiTestHelpers
  # Builds a Tui::Input over a pipe pre-seeded with scripted key bytes.
  # A pipe (not StringIO) is required: tty-reader calls wait_readable
  # for multi-byte sequences, and StringIO does not implement it.
  def input_for(bytes)
    reader, writer = IO.pipe
    writer.write(bytes)
    writer.close
    Letsdo::Tui::Input.new(stdin: reader, poll_timeout: 0)
  end

  # An injected size provider for the terminal (fixed terminal size).
  def size_provider(width, height)
    -> { [width, height] }
  end
end

# A keyboard that reports tty? and counts raw-mode entry/exit, so a test can
# assert the terminal state is restored after the session ends (TASK-83).
class RawTrackingStdin
  attr_reader :raw_enters, :raw_exits

  def initialize
    @raw_enters = 0
    @raw_exits = 0
  end

  def tty?
    true
  end

  def raw
    @raw_enters += 1
    yield
  ensure
    @raw_exits += 1
  end
end

# An input that scripts keys and exposes the raw-tracking stdin.
class ScriptedRawInput
  KEY_BY_CHAR = { 'q' => :q, 'p' => :p }.freeze

  attr_reader :stdin

  def initialize(keys)
    @stdin = RawTrackingStdin.new
    @keys = keys.dup
  end

  def next_key
    KEY_BY_CHAR[@keys.shift]
  end
end
