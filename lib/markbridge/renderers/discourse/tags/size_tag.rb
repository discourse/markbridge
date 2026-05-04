# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering sized text
        # Note: Discourse doesn't support inline size changes by default
        # Renders as plain text with HTML comment noting the size was lost
        class SizeTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if element.size
              # Render as HTML span with style - requires HTML to be enabled
              # Alternative: just output the text without size
              "<span style=\"font-size: #{element.size}px\">#{content}</span>"
            else
              content
            end
          end
        end
      end
    end
  end
end
