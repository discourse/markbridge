# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for URL tags
        class UrlHandler < BaseHandler
          def initialize
            @element_class = AST::Url
          end

          def on_open(token:, context:, registry:, tokens: nil)
            href = token.attrs[:href] || token.attrs[:url] || token.attrs[:option]
            element = AST::Url.new(href:)
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
