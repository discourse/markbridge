# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering images
        # Renders to Markdown image syntax with optional Discourse sizing:
        # `![alt|WIDTHxHEIGHT](url)`, `![alt|WIDTH](url)` or `![alt](url)`.
        class ImageTag < Tag
          # Whitespace with a line break in it, see #flat_alt.
          ALT_LINE_BREAK = /[[:space:]]*\n[[:space:]]*/
          # The parts after a `|` in the alt text that Discourse reads as
          # image options: a size (`100x100`, `100x100, 50%`), a media type
          # or `thumbnail`, and a data attribute (`key=value`). Spelled
          # after isKnownImageSuffix in Discourse's markdown-it engine.
          DISCOURSE_OPTION =
            /\A(?:[1-9][0-9]*x[1-9][0-9]*(?:[[:space:]]*,[[:space:]]*x?[1-9][0-9]{0,2}[%x]?)?|video|audio|thumbnail)\z/
          DATA_ATTRIBUTE = /\A[\w\-:.]*=/
          private_constant :ALT_LINE_BREAK, :DISCOURSE_OPTION, :DATA_ATTRIBUTE

          def render(element, interface)
            src = element.src
            width = element.width
            height = element.height
            alt = flat_alt(element.alt)

            if interface.html_mode?
              return render_html(src:, alt: HtmlEscaper.escape(alt), width:, height:)
            end

            # A height alone means nothing to Discourse.
            size = ("#{width}x#{height}" if width && height) || width

            label = alt && render_alt(alt, element:, interface:)
            "![#{label}#{"|" if ends_in_option?(alt)}#{"|#{size}" if size}](#{LinkDestination.escape(src)})"
          end

          private

          # A blank line in the alt text would end the paragraph, and with
          # it the image. The line breaks go, the words stay apart.
          def flat_alt(alt)
            alt&.gsub(ALT_LINE_BREAK, " ")
          end

          # Discourse walks the `|` parts of the alt text from the right and
          # takes every part that looks like an option as one, up to the
          # first part that does not. A backslash does not stop that, the
          # alt text is unescaped first. When the alt text itself ends in
          # such a part, an empty part after it stops the walk there: the
          # options we write still apply, the alt text keeps its last part
          # and gets a `|` at its end.
          def ends_in_option?(alt)
            index = alt&.rindex("|")
            return false if index.nil?

            last = alt[(index + 1)..]
            DISCOURSE_OPTION.match?(last) || DATA_ATTRIBUTE.match?(last)
          end

          # The alt text goes through the renderer like any other text, so
          # it is escaped for a Markdown link label. Most images have no
          # alt text, the caller skips the Text node and the render pass
          # for them.
          def render_alt(alt, element:, interface:)
            interface.render_node(AST::Text.new(alt), context: interface.with_parent(element))
          end

          def render_html(src:, alt:, width:, height:)
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
