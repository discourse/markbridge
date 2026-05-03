# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering strikethrough text
        class StrikethroughTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            return "<s>#{content}</s>" if interface.html_mode?

            interface.wrap_inline(content, "~~")
          end
        end
      end
    end
  end
end
