# frozen_string_literal: true

module Markbridge
  module AST
    # Base class for all AST elements that can contain children.
    # Elements form the structural nodes of the AST tree, while Text nodes are leaves.
    #
    # @example Creating an element with children
    #   element = AST::Bold.new
    #   element << AST::Text.new("hello")
    #   element << AST::Text.new(" world")
    #   element.children.size # => 1 (consecutive text nodes are merged)
    class Element < Node
      # @return [Array<Node>] the child nodes of this element
      attr_reader :children

      def initialize
        @children = []
      end

      # Add a child node to this element.
      # Consecutive Text nodes are automatically merged for optimization.
      #
      # @param child [Node] the node to add as a child
      # @return [Element] self for method chaining
      # @raise [TypeError] if child is not a Node instance
      #
      # @example Adding children
      #   element << AST::Text.new("hello")
      #   element << AST::Bold.new
      def <<(child)
        unless child.is_a?(Node)
          actual = child.nil? ? "nil" : child.class
          raise TypeError, "child must be a #{Markbridge::AST::Node} (got #{actual})"
        end

        if child.is_a?(Text) && children.last.is_a?(Text)
          @children.last.merge(child)
        else
          @children << child
        end

        self
      end
    end
  end
end
