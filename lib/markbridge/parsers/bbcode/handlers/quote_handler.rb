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
        # - [quote="username, post:123, topic:456"]text[/quote] (Discourse format)
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
            author, post, topic, username = extract_from_option(token)
            author ||= token.attrs[:author]

            {
              author:,
              post: token.attrs[:post] || post,
              topic: token.attrs[:topic] || topic,
              username: token.attrs[:username] || username,
            }
          end

          def extract_from_option(token)
            option = token.attrs[:option]
            return nil, nil, nil, nil unless option

            post = option[/,\s*post:(\d+)/, 1]
            return option, nil, nil, nil unless post

            # Discourse format: "username, post:123, topic:456" (topic optional,
            # order irrelevant between post: and topic:).
            username = option.split(",").first.strip
            topic = option[/,\s*topic:(\d+)/, 1]

            [username, post, topic, username]
          end
        end
      end
    end
  end
end
