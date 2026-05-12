# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering email links
        class EmailTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            text = interface.render_children(element, context: child_context)
            address = element.address

            return text unless address

            if interface.html_mode?
              %(<a href="mailto:#{HtmlEscaper.escape(address)}">#{text}</a>)
            else
              # MarkdownEscaper leaves ] alone in prose, but it's structural
              # inside a link label — escape it here to prevent early termination.
              "[#{text.gsub("]") { "\\]" }}](mailto:#{address})"
            end
          end
        end
      end
    end
  end
end
