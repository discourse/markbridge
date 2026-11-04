# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for URL tags
        # Supports:
        # - [url=https://example.com]text[/url]
        # - [url]https://example.com[/url], where the text is the href
        class UrlHandler < BaseHandler
          def initialize
            @element_class = AST::Url
          end

          def on_open(token:, context:, registry:, tokens: nil)
            href = token.attrs[:href] || token.attrs[:url] || token.attrs[:option]
            content = href ? nil : content_href(token:, tokens:)
            return context.push(AST::Url.new(href:), token:) unless content

            # The text and the closing tag that content_href looked at.
            tokens.next
            tokens.next
            context.add_child(AST::Url.new(href: content) << AST::Text.new(content))
          end

          attr_reader :element_class

          private

          # [url]https://example.com[/url] has its href in the text. Only
          # plain text followed by the closing tag counts: with tags inside
          # the text is no URL, and the element keeps a nil href.
          #
          # @return [String, nil]
          def content_href(token:, tokens:)
            text, close = tokens&.peek_ahead(2)
            return unless text.instance_of?(TextToken) && close.instance_of?(TagEndToken)
            return unless close.tag == token.tag

            href = text.text.strip
            href unless href.empty?
          end
        end
      end
    end
  end
end
