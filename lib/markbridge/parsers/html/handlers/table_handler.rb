# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for table tags (<table>)
        class TableHandler < BaseHandler
          def initialize
            @element_class = AST::Table
          end

          def process(element:, parent:)
            ast_element = AST::Table.new
            parent << ast_element
            ast_element
          end

          attr_reader :element_class
        end
      end
    end
  end
end
