# frozen_string_literal: true

module Letsdo
  # Assignee mismatch reporting for AgentLoop (TASK-96).
  #
  # The provider matches the configured assignee after normalization
  # (leading '@', whitespace, case), so legacy-stored values keep the loop
  # running — but every exact-match consumer (backlog --assignee, the
  # agent's own queries) misses them. This concern surfaces that deviation
  # as a once-per-run stderr hint instead of letting it pass silently.
  module AgentLoopAssigneeHints
    private

    # Warns once per run about assignees that matched only after
    # normalization. Providers without #assignee_variants (plain lambdas
    # in tests) are silently skipped.
    def report_assignee_variants
      variants = provider_assignee_variants
      return if @variants_hinted || variants.empty?

      @variants_hinted = true
      quoted = variants.map { |value| "'#{value}'" }.join(', ')
      @stderr.puts("letsdo: warning: tasks store assignee(s) #{quoted} instead of the handle " \
                   "'#{@handle}' - matched after normalization; store '#{@handle}' on the tasks " \
                   '(or set AGENT_ASSIGNEE_HANDLE) so exact-match filters find them')
    end

    def provider_assignee_variants
      return [] unless @task_provider.respond_to?(:assignee_variants)

      @task_provider.assignee_variants.to_a
    end
  end
end
