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
    #
    # @example Cell over two columns
    #   cell = AST::TableCell.new(colspan: 2)
    class TableCell < Element
      # @return [Integer, nil] the number of columns the cell covers when
      #   that is more than one
      attr_reader :colspan

      # @return [Integer, nil] the number of rows the cell covers when
      #   that is more than one
      attr_reader :rowspan

      # Create a new table cell.
      #
      # @param header [Boolean] whether this is a header cell (th)
      # @param colspan [Integer, String, nil] the columns the cell covers.
      #   A number as text is fine, the parsers pass the attribute as it
      #   is. Anything that is no whole number above one is no span.
      # @param rowspan [Integer, String, nil] the rows the cell covers
      def initialize(header: false, colspan: nil, rowspan: nil)
        super()
        @header = header
        @colspan = span(colspan)
        @rowspan = span(rowspan)
      end

      def header?
        @header
      end

      private

      def span(value)
        number = Integer(value.to_s, 10, exception: false)
        number if number && number > 1
      end
    end
  end
end
