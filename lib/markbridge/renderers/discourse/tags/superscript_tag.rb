# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering superscript text
        # Renders to HTML <sup> tag
        class SuperscriptTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            "<sup>#{content}</sup>"
          end
        end
      end
    end
  end
end
