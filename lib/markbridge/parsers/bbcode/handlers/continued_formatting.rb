# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      module Handlers
        # For the handlers of a list item and a table cell, which end the
        # one before them with everything that is still open in it.
        module ContinuedFormatting
          private

          # Bold, a color or a link that a new item or cell has ended goes
          # on in the new one: `[list][b][*]one[*]two[/b][/list]` has two
          # bold items, and `[td][b]one[td]two` two bold cells, like
          # s9e\TextFormatter reads them. A copy that nothing is put into
          # is taken away again at the end of the parse.
          #
          # @param elements [Array<AST::Element>] what was ended, the
          #   innermost first
          # @param context [ParserState]
          # @param registry [HandlerRegistry]
          def continue_formatting(elements, context, registry)
            elements.reverse_each do |element|
              next unless registry.auto_closeable?(element.class)

              context.reopen(element.dup.replace_children([]))
            end
          end
        end
      end
    end
  end
end
