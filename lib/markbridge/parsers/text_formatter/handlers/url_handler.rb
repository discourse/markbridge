# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for URL elements in s9e/TextFormatter XML
        #
        # Extracts the url attribute and creates an AST::Url node
        class UrlHandler < BaseHandler
          def initialize
            @element_class = AST::Url
          end

          def process(element:, parent:, processor: nil)
            attrs = extract_attributes(element)
            node = AST::Url.new(href: attrs[:url])
            parent << node

            # Return node to signal: process children into this node
            node
          end

          attr_reader :element_class
        end
      end
    end
  end
end
