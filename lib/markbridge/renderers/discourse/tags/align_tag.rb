# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering aligned text
        # Renders as HTML div with align attribute
        class AlignTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if element.alignment
              "<div align=\"#{element.alignment}\">#{content}</div>"
            else
              content
            end
          end
        end
      end
    end
  end
end
