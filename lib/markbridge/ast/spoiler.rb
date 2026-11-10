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
    #
    # @example Block spoiler, on lines of its own
    #   spoiler = AST::Spoiler.new(block: true)
    #   spoiler << AST::Text.new("Hidden content")
    class Spoiler < Element
      # @return [String, nil] the spoiler title/label
      attr_reader :title

      # @return [Boolean, nil] +true+ for a spoiler that is a block; anything
      #   else is a spoiler inside a line of text
      attr_reader :block

      # Create a new Spoiler element.
      #
      # @param title [String, nil] optional title for the spoiler
      # @param block [Boolean, nil] +true+ when the source shows the spoiler
      #   as a block of its own, like the [spoiler] of phpBB
      def initialize(title: nil, block: nil)
        super()
        @title = title
        @block = block
      end
    end
  end
end
