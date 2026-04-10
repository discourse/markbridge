# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for table cell elements (TD, TH)
        class TableCellHandler < BaseHandler
          def initialize
            @element_class = AST::TableCell
          end

          def process(element:, parent:)
            node = AST::TableCell.new(header: element.name.upcase == "TH")
            parent << node
            node
          end

          def element_class
            @element_class
          end
        end
      end
    end
  end
end
