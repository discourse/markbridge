# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a spoiler element (hidden content).
    #
    # @example Basic spoiler
    #   spoiler = AST::Spoiler.new
    #   spoiler << AST::Text.new("Hidden content")
    #
    # @example Spoiler with title
    #   spoiler = AST::Spoiler.new(title: "Click to reveal")
    #   spoiler << AST::Text.new("Hidden content")
    class Spoiler < Element
      # @return [String, nil] the spoiler title/label
      attr_reader :title

      # Create a new Spoiler element.
      #
      # @param title [String, nil] optional title for the spoiler
      def initialize(title: nil)
        super()
        @title = title
      end
    end
  end
end
