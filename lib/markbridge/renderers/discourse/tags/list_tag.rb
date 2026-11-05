# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class ListTag < Tag
          # An HTML comment between blank lines: invisible when cooked, and
          # a block of its own that ends the list before it. Inside a list
          # item the comment stands on a line of its own without blank
          # lines, which would make the item loose; ListItemTag takes the
          # line break in front of it off the content before it.
          LIST_SEPARATOR = "\n\n<!---->\n\n"
          NESTED_LIST_SEPARATOR = "\n<!---->"
          private_constant :NESTED_LIST_SEPARATOR

          # The output is the list, see Tag#leading_list.
          def leading_list(element, _interface)
            element
          end

          def trailing_list(element, _interface)
            element
          end

          def render(element, interface)
            child_context = interface.with_parent(element)

            content =
              element
                .children
                .map { |child| interface.render_node(child, context: child_context) }
                .join

            # A list without items renders to nothing, like the other
            # containers. Blank lines alone would still count as a list
            # for the separator between two lists of the same kind.
            return "" if content.empty?

            if interface.html_mode?
              tag_name = element.ordered? ? "ol" : "ul"
              return "<#{tag_name}>#{content}</#{tag_name}>"
            end

            # A list right inside a list item starts on the line after the
            # item text, so the list stays tight. ListItemTag takes care of
            # what follows it in the item. Everywhere else (also inside a
            # quote or an aligned block that sits in an item) the list is a
            # block with blank lines on both sides.
            parent = interface.context.element
            nested = parent.is_a?(AST::ListItem) || parent.is_a?(AST::List)
            list = nested ? "\n#{content}" : "\n\n#{content}\n\n"

            # Two lists of the same kind in a row need something between
            # them, or CommonMark reads the second as more items of the
            # first and the blank line makes the whole list loose. A change
            # of kind starts a new list on its own. Whitespace between
            # them, and nodes that render to nothing, do not keep them
            # apart; the renderer knows which list came last.
            previous = interface.previous_list(element)
            return list unless previous && previous.ordered? == element.ordered?

            "#{nested ? NESTED_LIST_SEPARATOR : LIST_SEPARATOR}#{list}"
          end
        end
      end
    end
  end
end
