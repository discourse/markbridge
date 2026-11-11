# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # Handler for list item tags (*, li)
        class ListItemHandler < BaseHandler
          def initialize
            @element_class = AST::ListItem
          end

          # A new item ends the item that is open, with everything that
          # is still open in it: `[*]a [b]bold[*]b` has two items, and
          # the bold ends with the first. With no item open, what is open
          # directly in the list ends: `[list][b]a[*]b` has two items
          # too. An item of a nested list leaves the item around that
          # list open.
          #
          # A `[*]` in a quote, a spoiler, an aligned block or a table
          # cell that is open in an item does not belong to the list
          # around that block. `[list][*]a [quote]b [*] c[/quote][/list]`
          # has one item, and the `[*]` in the quote is text, like
          # s9e\TextFormatter reads it. Without a list around the block
          # nothing changes: there a `[*]` starts an item.
          def on_open(token:, context:, registry:, tokens: nil)
            open = context.elements_from_current
            depth = open.index { |element| LIMITS.include?(element.class) }
            if depth
              limit = open.fetch(depth).class
              if ENCLOSING.include?(limit)
                if open.any? { |element| element.instance_of?(AST::List) }
                  return context.add_child(AST::Text.new(token.source))
                end
              else
                context.auto_close!(depth)
                (limit == AST::ListItem ? depth + 1 : depth).times { context.pop }
              end
            end

            context.push(AST::ListItem.new, token:)
          end

          attr_reader :element_class

          # A block inside an item that has its own content.
          ENCLOSING = [AST::Quote, AST::Spoiler, AST::Align, AST::TableCell].freeze
          # Where the search for what the new item ends stops.
          LIMITS = [AST::ListItem, AST::List, *ENCLOSING].freeze
          private_constant :ENCLOSING, :LIMITS
        end
      end
    end
  end
end
