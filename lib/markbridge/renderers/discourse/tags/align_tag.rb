# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering aligned text
        # Renders as HTML div with align attribute
        class AlignTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            return content unless element.alignment

            wrapper = %(<div align="#{element.alignment}">#{content}</div>)
            # Skip the trailing blank line in html_mode: a blank line would
            # terminate the surrounding HTML block (e.g. an enclosing <table>).
            interface.html_mode? ? wrapper : "#{wrapper}\n\n"
          end
        end
      end
    end
  end
end
