# frozen_string_literal: true

module Letsdo
  # Base error of the package.
  class Error < StandardError; end

  # An agent with this name was not found in agents/.
  class UnknownAgentError < Error
    attr_reader :name

    def initialize(name)
      @name = name
      super("Unknown agent: #{name}")
    end
  end
end