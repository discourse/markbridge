# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for table row tags (<tr>)
        class TableRowHandler < BaseHandler
          def initialize
            @element_class = AST::TableRow
          end

          def process(element:, parent:)
            ast_element = AST::TableRow.new
            parent << ast_element
            ast_element
          end

          attr_reader :element_class
        end
      end
    end
  end
end
