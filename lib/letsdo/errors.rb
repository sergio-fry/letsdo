# frozen_string_literal: true

module Letsdo
  # Base error of the package.
  class Error < StandardError; end

  # Raised by the signal handler to interrupt whatever the main thread is
  # doing (reading pi output, waiting for tasks, ...) so the loop unwinds
  # cleanly. Not a StandardError — nothing rescues it accidentally.
  class Stopped < StandardError
  end
end
