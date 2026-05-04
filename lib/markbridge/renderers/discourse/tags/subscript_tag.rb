# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering subscript text
        # Renders to HTML <sub> tag
        class SubscriptTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            "<sub>#{content}</sub>"
          end
        end
      end
    end
  end
end
