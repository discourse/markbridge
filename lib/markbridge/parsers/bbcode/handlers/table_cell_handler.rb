# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for table cell tags (td, th)
        class TableCellHandler < BaseHandler
          def initialize
            @element_class = AST::TableCell
          end

          def on_open(token:, context:, registry:, tokens: nil)
            # Auto-close previous cell if still open
            context.pop if context.current.is_a?(AST::TableCell)

            element = AST::TableCell.new(header: token.tag == "th")
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
