# frozen_string_literal: true

module Markbridge
  module AST
    # Represents an ordered or unordered list element.
    #
    # @example Unordered list
    #   list = AST::List.new
    #   list << AST::ListItem.new
    #
    # @example Ordered list
    #   list = AST::List.new(ordered: true)
    #   list << AST::ListItem.new
    class List < Element
      include Block

      # Add content to this list.
      # - ListItem children are added directly
      # - Other nodes are wrapped in an implicit ListItem
      # - Whitespace-only Text nodes are ignored
      #
      # @param child [Node] the node to add
      # @return [List] self for chaining
      # @raise [TypeError] if child is not a Node
      def <<(child)
        return self if child.instance_of?(Text) && !child.text.match?(/\S/)

        if child.instance_of?(ListItem)
          super
        else
          @children << ListItem.new if @children.empty?
          @children.last << child
        end

        self
      end

      # Create a new list element.
      #
      # @param ordered [Boolean] whether this is an ordered (numbered) list
      def initialize(ordered: false)
        super()
        @ordered = ordered
      end

      # Check if this is an ordered list.
      #
      # @return [Boolean] true if this is an ordered (numbered) list
      def ordered?
        @ordered
      end
    end
  end
end
