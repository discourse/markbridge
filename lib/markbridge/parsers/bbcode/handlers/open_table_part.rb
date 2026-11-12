# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # For the handlers that end a table cell or a row with a new one.
        module OpenTablePart
          # Blocks with their own content. A `[td]` or a `[tr]` in one of
          # them does not belong to the table around that block, and
          # nothing is ended for it.
          OWN_CONTENT = [AST::Quote, AST::Spoiler, AST::Align, AST::List, AST::ListItem].freeze
          private_constant :OWN_CONTENT

          private

          # Ends the cell that is open, with everything that is still
          # open in it: `[td][b]a[td]b` has two cells, and the bold ends
          # with the first. With no cell open, what is open directly in
          # the row ends. A cell of a table in the cell is left alone.
          #
          # @param context [ParserState]
          # @return [Array<AST::Element>] what was open in the cell or in
          #   the row, the innermost first
          def close_open_cell(context)
            open = context.elements_from_current
            depth =
              open.index do |element|
                element.instance_of?(AST::TableCell) || row_or_beyond?(element)
              end
            return [] unless depth && !beyond_row?(open.fetch(depth))

            context.auto_close!(depth)
            (open.fetch(depth).instance_of?(AST::TableCell) ? depth + 1 : depth).times do
              context.pop
            end
            open.first(depth)
          end

          # Ends the row that is open, with its cell and everything that
          # is still open in it. With no row open, what is open directly
          # in the table ends.
          #
          # @param context [ParserState]
          def close_open_row(context)
            open = context.elements_from_current
            depth = open.index { |element| row_or_beyond?(element) }
            return unless depth && !OWN_CONTENT.include?(open.fetch(depth).class)

            context.auto_close!(open.first(depth).count { |e| !e.instance_of?(AST::TableCell) })
            (open.fetch(depth).instance_of?(AST::TableRow) ? depth + 1 : depth).times do
              context.pop
            end
          end

          def row_or_beyond?(element)
            element.instance_of?(AST::TableRow) || beyond_row?(element)
          end

          def beyond_row?(element)
            element.instance_of?(AST::Table) || OWN_CONTENT.include?(element.class)
          end
        end
      end
    end
  end
end
