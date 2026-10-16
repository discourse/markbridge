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

            # A height alone means nothing to Discourse.
            size = ("#{width}x#{height}" if width && height) || width

            "![#{alt}#{"|#{size}" if size}](#{markdown_destination(src)})"
          end

          private

          # The alt text goes through the renderer like any other text, so
          # it is escaped for the place it lands in: a Markdown link label,
          # or an HTML attribute in html_mode. A missing alt renders to
          # nothing, the escapers turn nil into an empty string.
          def render_alt(element, interface)
            interface.render_node(
              AST::Text.new(element.alt),
              context: interface.with_parent(element),
            )
          end

          # An unbalanced parenthesis ends a CommonMark destination early. A
          # backslash of the source is doubled, or it would escape the
          # parenthesis after it, also the one that closes the destination.
          # Most image sources contain none of these characters, so the
          # match? in front saves the copy that gsub makes.
          def markdown_destination(src)
            src&.match?(/[()\\]/) ? src.gsub(/[()\\]/) { |char| "\\#{char}" } : src
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
