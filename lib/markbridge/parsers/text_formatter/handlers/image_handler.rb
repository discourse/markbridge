# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for IMG elements in s9e/TextFormatter XML
        class ImageHandler < BaseHandler
          def initialize
            @element_class = AST::Image
          end

          def process(element:, parent:, processor: nil)
            attrs = extract_attributes(element)
            node =
              AST::Image.new(
                src: attrs[:src],
                width: attrs[:width]&.to_i,
                height: attrs[:height]&.to_i,
              )
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
