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
            return context.add_child(AST::Text.new(token.source)) if enclosed?(context)

            close_open_item(context)

            element = AST::ListItem.new
            context.push(element, token:)
          end

          attr_reader :element_class

          # A block inside an item that has its own content. A `[*]` in
          # it does not belong to the list around the block.
          ENCLOSING = [AST::Quote, AST::Spoiler, AST::Align, AST::TableCell].freeze
          private_constant :ENCLOSING

          private

          # Whether a quote, a spoiler, an aligned block or a table cell
          # is open between here and the list. `[list][*]a [quote]b [*]
          # c[/quote][/list]` has one item, and the `[*]` in the quote is
          # text, like s9e\TextFormatter reads it. Without a list around
          # it nothing changes: there a `[*]` starts an item.
          def enclosed?(context)
            open = context.elements_from_current
            block = open.index { |element| ENCLOSING.include?(element.class) }
            list = open.index { |element| element.instance_of?(AST::List) }
            !block.nil? && !list.nil? && block < list
          end
        end
      end
    end
  end
end
