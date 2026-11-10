# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for list tags (list, ul, ol, etc.)
        class ListHandler < BaseHandler
          include OpenItem

          def initialize
            @element_class = AST::List
          end

          def on_open(token:, context:, registry:, tokens: nil)
            ordered =
              %w[ol olist].include?(token.tag) || token.attrs[:type] == "1" ||
                token.attrs[:option] == "1"

            element = AST::List.new(ordered:)
            context.push(element, token:)
          end

          def on_close(token:, context:, registry:, tokens: nil)
            close_open_item(context)
            close_to_list(context)
            super
          end

          attr_reader :element_class
        end
      end
    end
  end
end
