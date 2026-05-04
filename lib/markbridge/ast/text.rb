# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a text node (leaf node) in the AST.
    # Text nodes contain the actual text content and cannot have children.
    #
    # @example Creating a text node
    #   text = AST::Text.new("Hello, world!")
    #
    # @example Merging text nodes
    #   text1 = AST::Text.new("Hello")
    #   text2 = AST::Text.new(" world")
    #   text1.merge(text2)
    #   text1.text # => "Hello world"
    class Text < Node
      # @return [String] the text content of this node
      attr_reader :text

      # Create a new text node with the given content.
      #
      # The text is copied into a fresh mutable buffer so that subsequent
      # in-place mutations (e.g. via {#merge}) do not leak back to the caller's
      # original string.
      #
      # @param text [String] the text content
      def initialize(text)
        @text = String.new(text)
      end

      # Merge another text node's content into this one.
      # This mutates the current text node by appending the other's text.
      #
      # @param other [Text] the text node to merge from
      # @return [Text] self for method chaining
      def merge(other)
        @text << other.text
        self
      end
    end
  end
end
