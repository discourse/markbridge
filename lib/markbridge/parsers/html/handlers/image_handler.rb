# frozen_string_literal: true

module Markbridge
  module Parsers
    module HTML
      module Handlers
        # Handler for <img> tags
        class ImageHandler < BaseHandler
          def initialize
            @element_class = AST::Image
          end

          def process(element:, parent:)
            src = element["src"]
            width = sanitize_dimension(element["width"])
            height = sanitize_dimension(element["height"])

            ast_element = AST::Image.new(src:, width:, height:)
            parent << ast_element

            # Return nil to signal: don't process children (void element)
            nil
          end

          attr_reader :element_class

          private

          def sanitize_dimension(value)
            dim = value.to_i
            dim if dim.positive?
          end
        end
      end
    end
  end
end
