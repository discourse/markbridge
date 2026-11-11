# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for table row tags (tr)
        class TableRowHandler < BaseHandler
          include OpenTablePart

          def initialize
            @element_class = AST::TableRow
          end

          def on_open(token:, context:, registry:, tokens: nil)
            close_open_row(context)

            element = AST::TableRow.new
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
