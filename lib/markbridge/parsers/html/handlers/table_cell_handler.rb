# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for table cell tags (<td>, <th>)
        class TableCellHandler < BaseHandler
          def initialize
            @element_class = AST::TableCell
          end

          def process(element:, parent:)
            ast_element =
              AST::TableCell.new(
                header: element.name.downcase == "th",
                colspan: element["colspan"],
                rowspan: element["rowspan"],
              )
            parent << ast_element
            ast_element
          end

          attr_reader :element_class
        end
      end
    end
  end
end
