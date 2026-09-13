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
        agent_loop(name, streamer, stderr: @stderr, metrics: recorder).run
      ensure
        recorder.session_stop
        @stderr.puts(recorder.summary_line)
      end
    end
  end
end
