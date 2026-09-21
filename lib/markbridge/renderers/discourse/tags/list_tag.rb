# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class ListTag < Tag
          # An HTML comment between blank lines: invisible when cooked, and
          # a block of its own that ends the list before it.
          LIST_SEPARATOR = "\n\n<!---->\n\n"
          private_constant :LIST_SEPARATOR

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
            # item text, so the list stays tight. The blank line after it
            # keeps whatever follows in the item from becoming a
            # continuation line of the last nested item. Everywhere else
            # (also inside a quote or an aligned block that sits in an
            # item) the list is a block with blank lines on both sides.
            parent = interface.context.element
            list =
              if parent.is_a?(AST::ListItem) || parent.is_a?(AST::List)
                "\n#{content}\n"
              else
                "\n\n#{content}\n\n"
              end

            # Two lists of the same kind in a row need something between
            # them, or CommonMark reads the second as more items of the
            # first and the blank line makes the whole list loose. A change
            # of kind starts a new list on its own.
            previous = interface.previous_sibling(element)
            return list unless previous.is_a?(AST::List) && previous.ordered? == element.ordered?

            "#{LIST_SEPARATOR}#{list}"
          end
        end
      end
    end
  end
end
