# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for QUOTE elements in s9e/TextFormatter XML
        class QuoteHandler < BaseHandler
          def initialize
            @element_class = AST::Quote
          end

          def process(element:, parent:, processor: nil)
            attrs = extract_attributes(element)
            node =
              AST::Quote.new(
                author: attrs[:author],
                post: attrs[:post_id] || attrs[:post],
                topic: attrs[:topic_id] || attrs[:topic],
                username: attrs[:username],
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
