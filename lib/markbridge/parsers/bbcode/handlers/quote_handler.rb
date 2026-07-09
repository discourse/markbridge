# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for QUOTE tags
        # Supports:
        # - [quote]text[/quote]
        # - [quote=author]text[/quote]
        # - [quote="author"]text[/quote]
        # - [quote author=username]text[/quote]
        # - [quote="username, post:2, topic:456"]text[/quote] (Discourse format)
        #
        # Attribution semantics are Discourse's: `post:` is the post's
        # number within its topic and `topic:` is the topic id. Beware
        # when feeding other dialects through this handler — XenForo
        # attributions ("name, post: 12345, member: 678") also match the
        # `post:` pattern, but there the value is a database post id, not
        # a post number.
        class QuoteHandler < BaseHandler
          def initialize
            @element_class = AST::Quote
          end

          def on_open(token:, context:, registry:, tokens: nil)
            attrs = extract_quote_attrs(token)
            element = AST::Quote.new(**attrs)
            context.push(element, token:)
          end

          attr_reader :element_class

          private

          def extract_quote_attrs(token)
            author, post_number, topic_id, username = extract_from_option(token)
            author ||= token.attrs[:author]

            {
              author:,
              post_number: integer_or_nil(token.attrs[:post]) || post_number,
              topic_id: integer_or_nil(token.attrs[:topic]) || topic_id,
              username: token.attrs[:username] || username,
            }
          end

          def extract_from_option(token)
            option = token.attrs[:option]
            return nil, nil, nil, nil unless option

            post_number = option[/,\s*post:(\d+)/, 1]
            return option, nil, nil, nil unless post_number

            # Discourse format: "username, post:2, topic:456" (topic optional,
            # order irrelevant between post: and topic:).
            username = option.split(",").first.strip
            topic_id = option[/,\s*topic:(\d+)/, 1]

            # The regex captures are guaranteed digit runs, so strict
            # Integer() applies. Base 10 is explicit: without it a
            # leading zero switches Integer() to octal and "099" raises.
            [username, Integer(post_number, 10), topic_id && Integer(topic_id, 10), username]
          end

          # Coerce an attribute value to Integer; nil and non-numeric
          # values (which would make a useless attribution anyway)
          # become nil. Base 10 is explicit so leading zeros ("099")
          # don't trip Integer()'s octal mode and prefix forms ("0x1A")
          # don't smuggle in surprise values. The result is an unbounded
          # Ruby Integer — a runaway digit run like
          # "post:77777777777777777789999" parses to a bignum, so
          # consumers binding these into fixed-width storage (int64
          # columns) need their own bounds check.
          def integer_or_nil(value)
            Integer(value, 10, exception: false)
          end
        end
      end
    end
  end
end
