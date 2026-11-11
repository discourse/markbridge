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
            closing_handler = registry[token.tag]
            @reconciler.close_inside_block(handler: closing_handler, context:)
            @reconciler.close_item_without_list(handler: closing_handler, context:)
            current_handler = registry.handler_for_element(context.current)

            if current_handler == closing_handler
              context.pop
            elsif @reconciler.try_auto_close(handler: closing_handler, context:)
              # Auto-close succeeded
            else
              context.add_child(AST::Text.new(token.source))
            end
          end
        end
      end
    end
  end
end
