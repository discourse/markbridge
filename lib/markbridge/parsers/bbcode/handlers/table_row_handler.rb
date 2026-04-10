# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for table row tags (tr)
        class TableRowHandler < BaseHandler
          def initialize
            @element_class = AST::TableRow
          end

          def on_open(token:, context:, registry:, tokens: nil)
            # Auto-close open cell before starting new row
            context.pop if context.current.is_a?(AST::TableCell)
            # Auto-close previous row if still open
            context.pop if context.current.is_a?(AST::TableRow)

            element = AST::TableRow.new
            context.push(element, token:)
          end

          def on_close(token:, context:, registry:, tokens: nil)
            # Auto-close open cell before closing row
            context.pop if context.current.is_a?(AST::TableCell)

            super
          end

          attr_reader :element_class
        end
      end
    end
  end
end
