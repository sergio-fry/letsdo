# frozen_string_literal: true

module Letsdo
  module Providers
    # Immutable value object representing a normalized task.
    #
    # Adapters map tracker-specific JSON onto this shape. Business logic
    # consumes only this interface, not the raw tracker schema.
    class Task
      attr_reader :id, :title, :status, :priority, :assignees

      def initialize(id:, title: nil, status: nil, priority: nil, assignees: [])
        @id = id
        @title = title
        @status = status
        @priority = priority
        @assignees = Array(assignees)
        freeze
      end

      def to_s
        identifier = id.to_s
        return identifier unless identifier.empty?

        title.to_s
      end
    end
  end
end
