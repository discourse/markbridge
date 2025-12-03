# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for EMAIL tags
        # Similar to UrlHandler but for email addresses
        class EmailHandler < BaseHandler
          def initialize
            @element_class = AST::Email
          end

          def on_open(token:, context:, registry:, tokens: nil)
            address = token.attrs[:email] || token.attrs[:address] || token.attrs[:option]
            element = AST::Email.new(address:)
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
