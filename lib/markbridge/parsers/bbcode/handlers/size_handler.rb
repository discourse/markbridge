# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for SIZE tags
        # Supports:
        # - [size=20]text[/size]
        # - [size=large]text[/size]
        class SizeHandler < BaseHandler
          def initialize
            @element_class = AST::Size
          end

          def on_open(token:, context:, registry:, tokens: nil)
            size = token.attrs[:size] || token.attrs[:option]
            element = AST::Size.new(size:)
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
