# frozen_string_literal: true
module Markbridge
  module Parsers
    module BBCode
      module ClosingStrategies
        class Base
          def initialize(reconciler)
            @reconciler = reconciler
          end

          def handle_close(token:, context:, registry:, tokens: nil)
            return unless context.current.is_a?(AST::Element)

            current_handler = registry.handler_for_element(context.current)
            closing_handler = registry[token.tag]

            if current_handler == closing_handler
              context.pop
            elsif try_reorder(context:, tokens:, closing_handler:)
              # Reordering handled
            elsif @reconciler.try_auto_close(handler: closing_handler, context:)
              # Auto-close succeeded
            else
              context.add_child(AST::Text.new(token.source))
            end
          end

          private

          def try_reorder(context:, tokens:, closing_handler:)
            false
          end
        end
      end
    end
  end
end
