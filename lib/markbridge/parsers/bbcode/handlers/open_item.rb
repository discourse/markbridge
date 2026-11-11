# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # For the handler that ends a list item with a new item.
        module OpenItem
          private

          # Ends the item that is open, with everything that is still open
          # in it: `[*]a [b]bold[*]b` has two items, and the bold ends
          # with the first. The search stops at the list, so an item of a
          # nested list leaves the item around that list open.
          #
          # @param context [ParserState]
          def close_open_item(context)
            open = context.elements_from_current
            depth =
              open.index do |element|
                element.instance_of?(AST::ListItem) || element.instance_of?(AST::List)
              end
            return unless depth

            # With no item open, what is open directly in the list ends
            # here too: `[list][b]a[*]b` has two items, and the first
            # one is the bold.
            item = open.fetch(depth).instance_of?(AST::ListItem)
            context.auto_close!(depth)
            (item ? depth + 1 : depth).times { context.pop }
          end
        end
      end
    end
  end
end
