# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering images
        # Renders to Markdown image syntax with optional Discourse sizing:
        # `![alt|WIDTHxHEIGHT](url)`, `![alt|WIDTH](url)` or `![alt](url)`.
        class ImageTag < Tag
          def render(element, interface)
            src = element.src
            width = element.width
            height = element.height
            alt = render_alt(element, interface)

            return render_html(src, alt, width, height) if interface.html_mode?

            dimensions =
              if width && height
                "|#{width}x#{height}"
              elsif width
                "|#{width}"
              else
                ""
              end

            "![#{alt}#{dimensions}](#{src})"
          end

          private

          # The alt text goes through the renderer like any other text, so
          # it is escaped for the place it lands in: a Markdown link label,
          # or an HTML attribute in html_mode.
          def render_alt(element, interface)
            alt = element.alt
            return "" if alt.nil? || alt.empty?

            interface.render_node(AST::Text.new(alt), context: interface.with_parent(element))
          end

          def render_html(src, alt, width, height)
            attrs = %(src="#{HtmlEscaper.escape(src)}" alt="#{alt}")
            attrs << %( width="#{width}") if width
            attrs << %( height="#{height}") if height
            "<img #{attrs}>"
          end
        end
      end
    end
  end
end
