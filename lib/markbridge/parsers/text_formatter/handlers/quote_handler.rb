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
        #
        # A bare +topic+ attribute feeds {AST::Quote#topic_id} (a topic
        # reference is an id in every dialect we know). A bare +post+
        # attribute is deliberately NOT mapped: without knowing the
        # exporting platform it is undecidable whether it holds a post
        # id or a post number, and guessing wrong produces attributions
        # that link the wrong post. Register a custom handler when your
        # export carries one and you know its semantics.
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
                topic_id: integer_or_nil(attrs[:topic_id] || attrs[:topic]),
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
          # become nil. Base 10 is explicit so leading zeros ("099")
          # don't trip Integer()'s octal mode and prefix forms ("0x1A")
          # don't smuggle in surprise values. The result is an unbounded
          # Ruby Integer — a runaway digit string parses to a bignum,
          # so consumers binding these into fixed-width storage (int64
          # columns) need their own bounds check.
          def integer_or_nil(value)
            Integer(value, 10, exception: false)
          end
        end
      end
    end
  end
end
