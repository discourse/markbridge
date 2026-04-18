# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for list tags (list, ul, ol, etc.)
        class ListHandler < BaseHandler
          def initialize
            @element_class = AST::List
          end

          def on_open(token:, context:, registry:, tokens: nil)
            # Check if ordered: explicit ol/olist tag, or type=1, or option=1
            ordered =
              %w[ol olist].include?(token.tag) || token.attrs[:type] == "1" ||
                token.attrs[:option] == "1"

            element = AST::List.new(ordered:)
            context.push(element, token:)
          end

          def on_close(token:, context:, registry:, tokens: nil)
            # Auto-close open list item before closing list
            context.pop if context.current.instance_of?(AST::ListItem)

            # Then use default closing behavior
            super
          end

          attr_reader :element_class
        end
      end
    end
  end
end
