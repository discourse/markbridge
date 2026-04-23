# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a table element containing rows.
    #
    # @example
    #   table = AST::Table.new
    #   table << AST::TableRow.new
    class Table < Element
      # Add a child node to the table.
      # Whitespace-only Text nodes are ignored.
      #
      # @param child [Node] the node to add
      # @return [Table] self for chaining
      def <<(child)
        return self if child.is_a?(Text) && child.text.strip.empty?

        super
      end
    end

    # Represents a table row containing cells.
    #
    # @example
    #   row = AST::TableRow.new
    #   row << AST::TableCell.new
    class TableRow < Element
      # Add a child node to the row.
      # Whitespace-only Text nodes are ignored.
      #
      # @param child [Node] the node to add
      # @return [TableRow] self for chaining
      def <<(child)
        return self if child.is_a?(Text) && child.text.strip.empty?

        super
      end
    end

    # Represents a table cell (td or th).
    #
    # @example Data cell
    #   cell = AST::TableCell.new
    #   cell << AST::Text.new("data")
    #
    # @example Header cell
    #   cell = AST::TableCell.new(header: true)
    #   cell << AST::Text.new("header")
    class TableCell < Element
      # Create a new table cell.
      #
      # @param header [Boolean] whether this is a header cell (th)
      def initialize(header: false)
        super()
        @header = header
      end

      # Check if this is a header cell.
      #
      # @return [Boolean] true if this is a header cell
      def header?
        @header
      end
    end
  end
end
