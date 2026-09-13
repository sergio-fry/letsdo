# frozen_string_literal: true

module Letsdo
  class CLI
    # `letsdo doctor` dispatch (TASK-71): builds the environment self-check
    # from the same Letsdo::Config the rest of the CLI uses and returns its
    # exit code. `doctor` is a reserved name -- it never launches an agent.
    module CLIDoctor
      private

      def doctor_command
        Doctor.new(config: Config.new(env: @env), stdout: @stdout, stdin: @stdin).run
      end
    end
  end
end
