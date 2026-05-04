# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering colored text
        # Note: Discourse doesn't support inline color by default
        # Renders as plain text with HTML comment noting the color was lost
        class ColorTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if element.color
              # Render as HTML span with style - requires HTML to be enabled
              # Alternative: just output the text without color
              "<span style=\"color: #{element.color}\">#{content}</span>"
            else
              content
            end
          end
        end
      end
    end
  end
end
