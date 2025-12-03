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
            # Extract quote attributes
            author = nil
            post = nil
            topic = nil
            username = nil

            # Check for author attribute or option
            if token.attrs[:author]
              author = token.attrs[:author]
            elsif token.attrs[:option]
              # Parse Discourse-style quote: "username, post:123, topic:456"
              option = token.attrs[:option]
              if option.match?(/,\s*post:\d+/)
                # Discourse format with post/topic
                parts = option.split(",").map(&:strip)
                username = parts[0]
                parts[1..].each do |part|
                  if part =~ /^post:(\d+)$/
                    post = ::Regexp.last_match(1)
                  elsif part =~ /^topic:(\d+)$/
                    topic = ::Regexp.last_match(1)
                  end
                end
                author = username
              else
                # Simple author attribution
                author = option
              end
            end

            # Check for explicit username, post, topic attributes (override option if present)
            username = token.attrs[:username] if token.attrs[:username]
            post = token.attrs[:post] if token.attrs[:post]
            topic = token.attrs[:topic] if token.attrs[:topic]

            element = AST::Quote.new(author:, post:, topic:, username:)
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
