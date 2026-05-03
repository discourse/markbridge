# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering email links
        class EmailTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            text = interface.render_children(element, context: child_context)
            address = element.address

            return text unless address

            if interface.html_mode?
              %(<a href="mailto:#{HtmlEscaper.escape(address)}">#{text}</a>)
            else
              "[#{text}](mailto:#{address})"
            end
          end
        end
      end
    end
  end
end
