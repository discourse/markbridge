# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering bold text
        class BoldTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            return "<strong>#{content}</strong>" if interface.html_mode?

            interface.wrap_inline(content, "**")
          end
        end
      end
    end
  end
end
