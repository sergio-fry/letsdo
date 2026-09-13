# frozen_string_literal: true

module Letsdo
  class CLI
    # Session recorder and metrics-file wiring for Letsdo::CLI::Builder.
    # Kept in its own module so BuilderAssembly stays within the module-length
    # limit.
    module BuilderMetrics
      # Returns the IO for the LETSDO_METRICS_FILE, or nil if unset or
      # unwritable. Emits a warning to stderr on invalid path.
      def metrics_io
        path = @env['LETSDO_METRICS_FILE']
        return nil if path.nil? || path.empty?

        File.open(path, 'a', encoding: 'UTF-8')
      rescue SystemCallError, IOError => e
        @stderr.puts("letsdo: cannot open metrics file #{path}: #{e.message}")
        nil
      end

      private

      def build_recorder(name)
        Letsdo::SessionRecorder.new(name: name, handle: assignee_handle(name),
                                    metrics_io: metrics_io)
      end

      def run_plain(name, recorder)
        streamer = OutputStreamer.new(stdout: @stdout, stderr: @stderr)
        agent = agent_for(name, streamer)
        pause_gate = Control::PauseGate.new
        reader = plain_control_reader(agent, pause_gate)
        agent_loop(name, streamer, agent: agent, stderr: @stderr, metrics: recorder,
                                   pause_gate: pause_gate).run
      ensure
        reader&.stop
        finish_session(name, recorder)
      end

      # Plain-mode control (TASK-75): with a terminal stdin the reader maps
      # p/q to the same actions as the TUI keys — the shared PauseGate plus
      # the current backend (nil between runs is a no-op). Reader#start is a
      # no-op when stdin is not a terminal (pipes, CI), so stopping stays
      # signal-only there. The reader writes nothing, so the plain stream
      # stays byte-identical.
      def plain_control_reader(agent, pause_gate)
        Control::Reader.new(input: @stdin, pause_gate: pause_gate,
                            runner: -> { agent.backend }).tap(&:start)
      end

      # One shared stop path for plain and TUI mode (TASK-69/TASK-70): close
      # the recorder, optionally write per-task elapsed back into the task
      # records, then print the summary. Write-back failures are counted and
      # reported, never raised.
      def finish_session(name, recorder)
        recorder.session_stop
        not_written = task_time_comments(name, recorder)
        @stderr.puts(recorder.summary_line)
        @stderr.puts(comment_failure_line(not_written)) if not_written.positive?
      end

      # Opt-in (LETSDO_TASK_TIME_COMMENT=1): re-query the provider once at
      # stop and comment the elapsed time on runs whose task is gone. Off by
      # default — no subprocess, no task file mutation.
      def task_time_comments(name, recorder)
        return 0 unless @config.task_time_comment?

        writeback = TaskTimeWriteback.new(command: backlog_command, cwd: @root,
                                          env: ENV.to_h.merge(@env), stderr: @stderr)
        writeback.call(recorder.summary.runs, final_open_tasks(name))
      end

      def final_open_tasks(name)
        provider_for(assignee_handle(name)).call
      end

      def comment_failure_line(count)
        "letsdo: #{count} #{count == 1 ? 'comment' : 'comments'} not written"
      end
    end
  end
end
