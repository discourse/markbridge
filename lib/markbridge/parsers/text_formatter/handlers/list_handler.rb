# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for LIST elements in s9e/TextFormatter XML
        class ListHandler < BaseHandler
          def initialize
            @element_class = AST::List
          end

          def process(element:, parent:)
            attrs = extract_attributes(element)
            type_str = attrs[:type]
            # Ordered if type is not empty, disc, circle, or square
            ordered = !type_str.nil? && !["", "disc", "circle", "square"].include?(type_str)

            node = AST::List.new(ordered:)
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
