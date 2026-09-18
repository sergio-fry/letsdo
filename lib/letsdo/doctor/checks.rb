# frozen_string_literal: true

module Letsdo
  class Doctor
    # The individual environment checks behind `letsdo doctor` (TASK-71).
    # Every check returns { status:, message:, hint: } where the hint is
    # mandatory for FAIL/WARN so the report is always actionable. Kept in its
    # own module so Letsdo::Doctor stays within the class-length limit.
    module DoctorChecks
      MINIMUM_RUBY = '3.3'

      private

      def checks
        [ruby_check, pi_check, backlog_check, assignee_check,
         root_check, agents_md_check, agents_dir_check, tty_check]
      end

      # ruby >= 3.3 is the gemspec floor: below it letsdo still reports the
      # problem as a WARN instead of a hard failure.
      def ruby_check
        return result('OK', "ruby #{RUBY_VERSION} (>= #{MINIMUM_RUBY})") if ruby_supported?

        result('WARN', "ruby #{RUBY_VERSION} (< #{MINIMUM_RUBY})",
               "upgrade Ruby to #{MINIMUM_RUBY} or newer")
      end

      def ruby_supported?
        Gem::Version.new(RUBY_VERSION) >= Gem::Version.new(MINIMUM_RUBY)
      end

      def pi_check
        command_check('pi', @config.pi_command, 'LETSDO_PI_COMMAND')
      end

      def backlog_check
        command_check('backlog', @config.backlog_command, 'LETSDO_BACKLOG_COMMAND')
      end

      # Assignee-name convention (TASK-96): the tracker stores bare names
      # ('developer'); '@' is prompt-only notation. The backlog CLI matches
      # --assignee by exact string, so a legacy @-prefixed stored assignee
      # (or handle override) is invisible to every exact-match query.
      # letsdo still matches such tasks after normalization, but the
      # deviation deserves a WARN so the data gets fixed. Uses a handle-less
      # provider (no filtering) and reads the raw assignees; an unreadable
      # backlog is reported as INFO because backlog_check already flags the
      # cause.
      def assignee_check
        override = @config.assignee_handle_override
        return warn_at_prefixed_override(override) if at_prefixed?(override)

        tasks = provider_without_handle.call
        return result('INFO', 'assignee names not checked - backlog task list failed') if tasks.nil?

        warn_legacy_assignees(tasks)
      end

      # A handle-less provider sees every open task, so the check reads the
      # raw stored assignees (no filtering, no variants recorded).
      def provider_without_handle
        Letsdo::Providers::Backlog.new(handle: nil, command: @config.backlog_command,
                                       cwd: @config.root, env: @config.child_env)
      end

      def warn_legacy_assignees(tasks)
        legacy = tasks.flat_map(&:assignees).select { |value| at_prefixed?(value) }.uniq.sort
        return result('OK', 'assignee names are stored bare (canonical)') if legacy.empty?

        quoted = legacy.map { |value| "'#{value}'" }.join(', ')
        result('WARN', "tasks store legacy @-prefixed assignee(s): #{quoted}",
               'reassign them to bare names: backlog task edit <ID> -a <name>')
      end

      def warn_at_prefixed_override(override)
        result('WARN', "AGENT_ASSIGNEE_HANDLE '#{override}' carries the legacy '@' prefix",
               "set it to the bare name: AGENT_ASSIGNEE_HANDLE=#{override.sub(/\A@+/, '')}")
      end

      # '@developer' is prose notation; the canonical tracker value is the
      # bare name, so any leading '@' is a legacy deviation worth a WARN.
      def at_prefixed?(value)
        value.to_s.strip.start_with?('@')
      end

      def command_check(label, command, env_var)
        return result('OK', "#{label} command found: #{command}") if command_available?(command)

        result('FAIL', "#{label} command not found: #{command}",
               "install #{label} or set #{env_var}")
      end

      # An absolute or relative command path is checked directly; a bare name
      # is resolved against the PATH exposed by Letsdo::Config.
      def command_available?(command)
        return File.executable?(command) if command.include?(File::SEPARATOR)

        @config.path.split(File::PATH_SEPARATOR).any? do |dir|
          File.executable?(File.join(dir, command))
        end
      end

      def root_check
        return result('OK', "project root #{@config.root} has backlog/tasks/") if backlog_tasks?

        result('FAIL', "project root #{@config.root} has no backlog/tasks/",
               'run `backlog init` or set LETSDO_ROOT to a Backlog.md project')
      end

      def backlog_tasks?
        File.directory?(File.join(@config.root, 'backlog', 'tasks'))
      end

      def agents_md_check
        path = File.join(@config.root, 'AGENTS.md')
        return result('OK', "AGENTS.md present at #{path}") if File.file?(path)

        result('WARN', "no AGENTS.md at #{path}",
               'add AGENTS.md with the project instructions for agents')
      end

      def agents_dir_check
        dir = File.join(@config.root, 'agents')
        prompts = File.directory?(dir) ? Dir.children(dir).length : 0
        return result('OK', "agents/ present with #{prompts} prompt(s)") if prompts.positive?

        result('WARN', "agents/ missing or empty at #{dir}",
               'create an agent prompt with `letsdo <name> --init`')
      end

      # TUI engages only when stdout is a TTY (plus stdin/TERM, checked at
      # launch); an INFO line tells the user which mode a run would pick.
      def tty_check
        return result('INFO', 'stdout is a TTY - TUI mode') if @stdout.tty?

        result('INFO', 'stdout is not a TTY - plain mode')
      end

      def result(status, message, hint = nil)
        { status: status, message: message, hint: hint }
      end
    end
  end
end
