# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a table element containing rows.
    #
    # @example
    #   table = AST::Table.new
    #   table << AST::TableRow.new
    class Table < Element
      # HTML/BBCode parsers add a Text("\n") child for the whitespace
      # between `<table>` and `<tr>` (and equivalent BBCode). Drop
      # those so the AST contains only TableRow children.
      def <<(child)
        return self if child.instance_of?(Text) && child.text.strip.empty?

        super
      end
    end

    # Represents a table row containing cells.
    #
    # @example
    #   row = AST::TableRow.new
    #   row << AST::TableCell.new
    class TableRow < Element
      # See Table#<< — same whitespace skip for `<tr>` / `<td>` gaps.
      def <<(child)
        return self if child.instance_of?(Text) && child.text.strip.empty?

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
