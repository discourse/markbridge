# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for raw/preformatted tags that preserve content as-is
        class RawHandler < BaseHandler
          def initialize(element_class)
            @element_class = element_class
          end

          def process(element:, parent:)
            # Get the inner text content
            content = element.inner_text

            # Extract language from class or lang attribute
            language = element["class"] || element["lang"]

            ast_element = @element_class.new(language:)
            ast_element << AST::Text.new(content) unless content.empty?
            parent << ast_element

            # Return nil to signal: don't process children (we handled content directly)
            nil
          end

          attr_reader :element_class
        end
      end
    end
  end
end
