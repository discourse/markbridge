# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a heading element with a level (1-6).
    #
    # @example
    #   heading = AST::Heading.new(level: 2)
    #   heading << AST::Text.new("Section Title")
    class Heading < Element
      # @return [Integer] the heading level (1-6)
      attr_reader :level

      # Create a new heading element.
      #
      # @param level [Integer] the heading level (1-6)
      def initialize(level:)
        super()
        @level = level
      end
    end
  end
end
