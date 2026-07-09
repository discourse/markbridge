# frozen_string_literal: true

module Markbridge
  module Parsers
    module TextFormatter
      module Handlers
        # Handler for QUOTE elements in s9e/TextFormatter XML
        #
        # Maps phpBB-style attribution attributes: +post_id+ and
        # +user_id+ are database ids and land in {AST::Quote#post_id} /
        # {AST::Quote#user_id} — deliberately not in
        # {AST::Quote#post_number}, which carries Discourse post-number
        # semantics that s9e exports don't provide.
        class QuoteHandler < BaseHandler
          def initialize
            @element_class = AST::Quote
          end

          def process(element:, parent:, processor: nil)
            attrs = extract_attributes(element)
            node =
              AST::Quote.new(
                author: attrs[:author],
                post_id: integer_or_nil(attrs[:post_id]),
                topic_id: integer_or_nil(attrs[:topic_id]),
                username: attrs[:username],
                user_id: integer_or_nil(attrs[:user_id]),
              )
            parent << node

            # Return node to signal: process children into this node
            node
          end

          attr_reader :element_class

          private

          # Coerce an attribute value to Integer; nil and non-numeric
          # values (which would make a useless attribution anyway)
          # become nil.
          def integer_or_nil(value)
            Integer(value, exception: false)
          end
        end
      end
    end
  end
end
