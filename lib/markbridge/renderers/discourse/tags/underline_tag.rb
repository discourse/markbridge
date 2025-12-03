# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering underline text
        class UnderlineTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            # Discourse uses HTML for underline
            "<u>#{content}</u>"
          end
        end
      end
    end
  end
end
