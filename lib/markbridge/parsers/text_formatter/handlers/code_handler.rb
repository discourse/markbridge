# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for CODE elements in s9e/TextFormatter XML
        class CodeHandler < BaseHandler
          def initialize
            @element_class = AST::Code
          end

          def process(element:, parent:, processor: nil)
            attrs = extract_attributes(element)
            lang = attrs[:lang] || attrs[:language]
            node = AST::Code.new(language: lang)
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
