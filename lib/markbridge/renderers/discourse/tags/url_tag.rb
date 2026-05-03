# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering URLs
        class UrlTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            text = interface.render_children(element, context: child_context)
            href = element.href

            return text unless href&.match?(/\A(?:https?|ftps?|mailto):/i)

            if interface.html_mode?
              %(<a href="#{HtmlEscaper.escape(href)}">#{text}</a>)
            else
              "[#{text}](#{href})"
            end
          end
        end
      end
    end
  end
end
