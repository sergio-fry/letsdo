# frozen_string_literal: true

module Letsdo
  module Providers
    # Immutable value object representing a normalized task.
    #
    # Adapters map tracker-specific JSON onto this shape. Business logic
    # consumes only this interface, not the raw tracker schema.
    #
    # The constructor is strict on purpose: adapters project the tracker
    # payload onto these keywords instead of forwarding it, so extra tracker
    # fields never reach here and a wrong key is caught as a programming
    # error instead of silently ignored.
    #
    # Besides the identity/routing fields, the shape carries the fields a
    # deterministic selector needs: +ordinal+ (the stable tie-break), and
    # +type+/+labels+/+milestone+ for optional capability routing.
    class Task
      attr_reader :id, :title, :status, :priority, :assignees,
                  :ordinal, :type, :labels, :milestone

      # rubocop:disable Metrics/ParameterLists -- the keywords are the
      # normalized shape's explicit contract; adapters project tracker
      # payloads onto exactly these and the strict list rejects a typo.
      def initialize(id:, title: nil, status: nil, priority: nil, assignees: [],
                     ordinal: nil, type: nil, labels: [], milestone: nil)
        @id = id
        @title = title
        @status = status
        @priority = priority
        @assignees = Array(assignees)
        @ordinal = ordinal
        @type = type
        @labels = Array(labels)
        @milestone = milestone
        freeze
      end
      # rubocop:enable Metrics/ParameterLists

      def to_s
        identifier = id.to_s
        return identifier unless identifier.empty?

        title.to_s
      end
    end
  end
end
