# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class HeadingTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if interface.html_mode?
              level = element.level.clamp(1, 6)
              return "<h#{level}>#{content}</h#{level}>"
            end

            prefix = "#" * element.level

            "#{prefix} #{content}\n\n"
          end
        end
      end
    end
  end
end
