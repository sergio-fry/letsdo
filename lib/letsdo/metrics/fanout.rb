# frozen_string_literal: true

module Letsdo
  module Metrics
    # A small fan-out facade that forwards the loop-driver events to a
    # list of observers.  Used in TUI mode so the session recorder and
    # the header metrics facade both receive the same callbacks from
    # Letsdo::AgentLoop.
    #
    # Each observer must respond to provider_result, run_started and
    # run_finished (the same interface Tui::Metrics and SessionRecorder
    # implement).  The exit code is forwarded to every observer so the
    # session recorder can classify outcomes; Tui::Metrics ignores it.
    class Fanout
      # @param observers [Array<Object>] each must implement the three
      #        callback methods (provider_result, run_started, run_finished)
      def initialize(*observers)
        @observers = observers
      end

      # Forwards the provider open-task count to every observer.
      #
      # @param count [Integer, nil] number of open tasks; nil = the
      #        backlog state is unreadable
      # @return [void]
      def provider_result(count)
        @observers.each { |observer| observer.provider_result(count) }
      end

      # Forwards a run-started event (task label) to every observer.
      #
      # @param task [String] task label
      # @return [void]
      def run_started(task)
        @observers.each { |observer| observer.run_started(task) }
      end

      # Forwards a run-finished event (exit code) to every observer.
      #
      # @param exit_code [Integer, nil] the run exit code
      # @return [void]
      def run_finished(exit_code = nil)
        @observers.each { |observer| observer.run_finished(exit_code) }
      end
    end
  end
end
