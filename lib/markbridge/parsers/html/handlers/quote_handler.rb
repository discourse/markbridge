# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for <blockquote> tags
        class QuoteHandler < BaseHandler
          def initialize
            @element_class = AST::Quote
          end

          def process(element:, parent:)
            # Extract optional author from cite attribute
            author = element["cite"]
            ast_element = AST::Quote.new(author:)
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
