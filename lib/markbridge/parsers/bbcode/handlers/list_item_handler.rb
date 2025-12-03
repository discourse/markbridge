# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for list item tags (*, li, .)
        class ListItemHandler < BaseHandler
          def initialize
            @element_class = AST::ListItem
          end

          def on_open(token:, context:, registry:, tokens: nil)
            # Auto-close previous list item if opening a new one
            context.pop if context.current.is_a?(AST::ListItem)

            element = AST::ListItem.new
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
