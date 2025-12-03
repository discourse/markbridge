# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering URLs
        class UrlTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            text = interface.render_children(element, context: child_context)
            href = element.href

            if href&.match?(/^(https?|ftps?|mailto):/i)
              "[#{text}](#{href})"
            else
              text
            end
          end
        end
      end
    end
  end
end
