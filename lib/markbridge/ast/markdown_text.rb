# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a text node containing pre-formatted Markdown content.
    # Unlike AST::Text, this content will NOT be escaped by the renderer.
    # Use this when you want to pass through Markdown formatting as-is.
    #
    # @example Creating a markdown text node
    #   text = AST::MarkdownText.new("**bold** and *italic*")
    #
    # @example Use case: preserving user-provided Markdown
    #   # When parsing HTML or other formats that allow embedded Markdown
    #   element << AST::MarkdownText.new(markdown_content)
    class MarkdownText < Node
      # @return [String] the markdown text content of this node
      attr_reader :text

      # Create a new markdown text node with the given content.
      #
      # @param text [String] the markdown text content
      def initialize(text)
        @text = +text
      end

      # Merge another markdown text node's content into this one.
      # This mutates the current text node by appending the other's text.
      #
      # @param other [MarkdownText] the text node to merge from
      # @return [MarkdownText] self for method chaining
      def merge(other)
        @text << other.text
        self
      end
    end
  end
end
