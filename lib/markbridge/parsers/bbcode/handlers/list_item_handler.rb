# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for list item tags (*, li)
        class ListItemHandler < BaseHandler
          include OpenItem

          def initialize
            @element_class = AST::ListItem
          end

          def on_open(token:, context:, registry:, tokens: nil)
            close_open_item(context)

            element = AST::ListItem.new
            context.push(element, token:)
          end

          attr_reader :element_class
        end
      end
    end
  end
end
