# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for list item tags (<li>)
        class ListItemHandler < BaseHandler
          def initialize
            @element_class = AST::ListItem
          end

          def process(element:, parent:)
            ast_element = AST::ListItem.new
            parent << ast_element

            # Return element to signal: process children into this element
            ast_element
          end

          attr_reader :element_class
        end
      end
    end
  end
end
