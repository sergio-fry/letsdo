# frozen_string_literal: true

module Letsdo
  # Shared rendering of a duration in seconds as "4m 12s" / "12s" / "0s".
  #
  # The stop summary (TASK-69) and the opt-in per-task elapsed write-back
  # (TASK-70) both use this one formatter, so the number a session reports
  # and the number written into the task record can never drift apart.
  module Duration
    module_function

    # @param seconds [Numeric] duration in seconds (negative values clamp to 0)
    # @return [String] human-readable duration, e.g. "4m 12s"
    def format(seconds)
      total = [seconds.to_f, 0.0].max.round
      minutes, secs = total.divmod(60)
      return '0s' if minutes.zero? && secs.zero?
      return "#{secs}s" if minutes.zero?

      "#{minutes}m #{secs}s"
    end
  end
end
