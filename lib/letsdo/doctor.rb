# frozen_string_literal: true

require_relative 'doctor/checks'

module Letsdo
  # `letsdo doctor`: one line per environment check with a status tag and an
  # actionable hint for every FAIL/WARN (TASK-71). Exits 0 when nothing
  # FAILs and 1 otherwise, so it can gate scripts.
  #
  # Every input comes from Letsdo::Config (env policy) plus the injected
  # streams, so the command is fully testable without touching process ENV.
  class Doctor
    include DoctorChecks

    def initialize(config:, stdout:, stdin: $stdin)
      @config = config
      @stdout = stdout
      @stdin = stdin
    end

    # Prints the report and returns the process exit code: 1 when at least
    # one check FAILed, 0 otherwise.
    def run
      results = checks
      results.each { |check| print_result(check) }
      results.any? { |check| check[:status] == 'FAIL' } ? 1 : 0
    end

    private

    def print_result(check)
      line = "[#{tag(check[:status])}] #{check[:message]}"
      line += " - #{check[:hint]}" if check[:hint]
      @stdout.puts(line)
    end

    # All tags render six characters wide, so the columns line up.
    def tag(status)
      status == 'OK' ? ' OK ' : status
    end
  end
end
