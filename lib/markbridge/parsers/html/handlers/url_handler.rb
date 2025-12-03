# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for <a> tags
        class UrlHandler < BaseHandler
          def initialize
            @element_class = AST::Url
          end

          def process(element:, parent:)
            href = element["href"]
            ast_element = AST::Url.new(href:)
            parent << ast_element

            # Return element to signal: process children into this element (link text)
            ast_element
          end

          attr_reader :element_class
        end
      end
    end
  end
end
