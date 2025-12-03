# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Simple formatting handlers that create an element and process children
        class SimpleHandler < BaseHandler
          def initialize(element_class)
            @element_class = element_class
          end

          def process(element:, parent:)
            ast_element = @element_class.new
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
