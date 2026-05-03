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

          # on_close is inherited from BaseHandler. SelfClosing elements are
          # never pushed onto the stack, so the registry's closing strategy
          # always falls through to adding the closing-tag source as text -
          # the same result as a dedicated override.

          attr_reader :element_class
        end
      end
    end
  end
end
