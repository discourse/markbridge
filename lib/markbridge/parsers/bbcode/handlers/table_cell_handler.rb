# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for table cell tags (td, th)
        class TableCellHandler < BaseHandler
          include OpenTablePart

          def initialize
            @element_class = AST::TableCell
          end

          def on_open(token:, context:, registry:, tokens: nil)
            close_open_cell(context)

            element =
              AST::TableCell.new(
                header: token.tag == "th",
                colspan: token.attrs[:colspan],
                rowspan: token.attrs[:rowspan],
              )
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
