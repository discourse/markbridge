# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering lists
        class ListTag < Tag
          def render(element, interface)
            # Create new context with this list as parent
            child_context = interface.with_parent(element)

            content =
              element
                .children
                .map { |child| interface.render_node(child, context: child_context) }
                .join

            # Check if we're nested - either inside another List OR inside a ListItem
            has_list_parent = interface.has_parent?(AST::List)
            has_list_item_parent = interface.has_parent?(AST::ListItem)
            nested = has_list_parent || has_list_item_parent

            if nested
              # Nested list: add leading newline so it starts on its own line
              "\n#{content}"
            else
              # Top-level list: add spacing
              "\n\n#{content}\n\n"
            end
          end
        end
      end
    end
  end
end
