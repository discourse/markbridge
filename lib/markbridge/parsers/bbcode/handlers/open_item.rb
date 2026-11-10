# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # For the handlers that end a list item: a new item and the end of
        # the list.
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
                element.instance_of?(AST::ListItem) || element.is_a?(AST::List)
              end
            return unless depth && open.fetch(depth).instance_of?(AST::ListItem)

            context.auto_close!(depth) if depth.positive?
            (depth + 1).times { context.pop }
          end

          # Ends what is still open directly in the list, outside of an
          # item: `[list]text [b]bold[/list]`. Without a list around it
          # nothing is closed.
          #
          # @param context [ParserState]
          def close_to_list(context)
            depth = context.elements_from_current.index { |element| element.is_a?(AST::List) }
            return unless depth&.positive?

            context.auto_close!(depth)
            depth.times { context.pop }
          end
        end
      end
    end
  end
end
