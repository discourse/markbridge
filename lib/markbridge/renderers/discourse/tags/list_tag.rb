# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class ListTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)

            content =
              element
                .children
                .map { |child| interface.render_node(child, context: child_context) }
                .join

            if interface.html_mode?
              tag_name = element.ordered? ? "ol" : "ul"
              return "<#{tag_name}>#{content}</#{tag_name}>"
            end

            nested = interface.has_parent?(AST::List) || interface.has_parent?(AST::ListItem)

            if nested
              "\n#{content}"
            else
              "\n\n#{content}\n\n"
            end
          end
        end
      end
    end
  end
end
