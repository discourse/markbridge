# frozen_string_literal: true

module Markbridge
  module AST
    # Base class for all AST nodes.
    # This is a marker class that serves as the common ancestor for all AST nodes.
    #
    # The AST hierarchy consists of:
    # - {Element} - nodes that can contain children
    # - {Text} - leaf nodes containing text content
    #
    # All node types inherit from this base class to enable type checking
    # and polymorphic operations on the AST tree.
    #
    # @abstract Subclass and add specific behavior
    class Node
    end
  end
end
