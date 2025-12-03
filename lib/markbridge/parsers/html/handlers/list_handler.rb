# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for list tags (<ul>, <ol>)
        class ListHandler < BaseHandler
          def initialize
            @element_class = AST::List
          end

          def process(element:, parent:)
            # Check if ordered: <ol> tag
            ordered = element.name.downcase == "ol"

            ast_element = AST::List.new(ordered:)
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
