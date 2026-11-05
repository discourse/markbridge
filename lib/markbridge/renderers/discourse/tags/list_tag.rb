# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class ListTag < Tag
          # The output is the list, see Tag#leading_list.
          def leading_list(element, _interface)
            element
          end

          def trailing_list(element, _interface)
            element
          end

          def render(element, interface)
            child_context = interface.with_parent(element)

            # Two lists of the same kind in a row would cook as one list,
            # and the blank line between them would make it loose. A
            # different marker starts a new list, so the renderer picks
            # the one the list in front did not use, and the items write
            # it (ListItemTag).
            unless interface.html_mode?
              interface.choose_list_marker(element, ordered: element.ordered?)
            end

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
            nested ? "\n#{content}" : "\n\n#{content}\n\n"
          end
        end
      end
    end
  end
end
