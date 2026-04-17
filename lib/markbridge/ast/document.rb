# frozen_string_literal: true

module Markbridge
  module AST
    # Represents the root document node of the AST.
    # This is the top-level container that holds all other elements.
    #
    # @example Creating a document
    #   doc = AST::Document.new
    #   doc << AST::Text.new("Hello, world!")
    #
    # @example Creating a document with initial children
    #   doc = AST::Document.new([
    #     AST::Text.new("Hello"),
    #     AST::Bold.new
    #   ])
    class Document < Element
      # Create a new document node.
      #
      # @param children [Array<Node>] optional array of initial child nodes
      def initialize(children = [])
        super()
        children.each { |c| self << c }
      end
    end
  end
end
