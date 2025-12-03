# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for COLOR tags
        # Supports:
        # - [color=red]text[/color]
        # - [color=#FF0000]text[/color]
        class ColorHandler < BaseHandler
          def initialize
            @element_class = AST::Color
          end

          def on_open(token:, context:, registry:, tokens: nil)
            color = token.attrs[:color] || token.attrs[:option]
            element = AST::Color.new(color:)
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
