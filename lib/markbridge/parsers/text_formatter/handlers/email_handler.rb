# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for EMAIL elements in s9e/TextFormatter XML
        class EmailHandler < BaseHandler
          def initialize
            @element_class = AST::Email
          end

          def process(element:, parent:, processor: nil)
            attrs = extract_attributes(element)
            node = AST::Email.new(address: attrs[:email])
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
