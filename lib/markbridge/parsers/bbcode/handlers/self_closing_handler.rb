# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for self-closing tags (br, hr, etc.)
        class SelfClosingHandler < BaseHandler
          def initialize(element_class)
            @element_class = element_class
          end

          def on_open(token:, context:, registry:, tokens: nil)
            element = @element_class.new
            context.add_child(element)
          end

          def on_close(token:, context:, registry:, tokens: nil)
            # Treat unexpected closing tag as text
            context.add_child(AST::Text.new(token.source))
          end

          attr_reader :element_class
        end
      end
    end
  end
end
