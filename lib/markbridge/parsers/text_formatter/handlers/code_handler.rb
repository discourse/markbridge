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
            # s9e CODE is always a block, so the flag keeps the fenced form
            # even for single-line content.
            node = AST::Code.new(language: lang, block: true)
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
