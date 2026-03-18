# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering headings
        # Renders as ATX-style Markdown headings (# through ######)
        class HeadingTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            prefix = "#" * element.level

            "#{prefix} #{content}\n\n"
          end
        end
      end
    end
  end
end
