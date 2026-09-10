# frozen_string_literal: true

module Letsdo
  # Base error of the package.
  class Error < StandardError; end

  # Raised by the signal handler to interrupt whatever the main thread is
  # doing (reading pi output, waiting for tasks, ...) so the loop unwinds
  # cleanly. Not a StandardError — nothing rescues it accidentally.
  class Stopped < StandardError
  end

  # Raised when the AI backend process cannot be started (missing or
  # non-executable binary). This is a configuration error, not a loop
  # problem: the CLI catches it, prints a clear message and exits 2 instead
  # of dying with a Ruby backtrace.
  class BackendUnavailableError < Error
  end
end
