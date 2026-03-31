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

            # Explicit attributes override option-parsed values
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

            unless option.match?(/,\s*post:\d+/)
              # Simple author attribution
              return option, nil, nil, nil
            end

            # Discourse format: "username, post:123, topic:456"
            parts = option.split(",").map(&:strip)
            username = parts[0]
            post = nil
            topic = nil

            parts[1..].each do |part|
              if part =~ /^post:(\d+)$/
                post = ::Regexp.last_match(1)
              elsif part =~ /^topic:(\d+)$/
                topic = ::Regexp.last_match(1)
              end
            end

            [username, post, topic, username]
          end
        end
      end
    end
  end
end
