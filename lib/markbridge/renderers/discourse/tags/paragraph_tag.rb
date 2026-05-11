# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering paragraphs
        # Paragraphs are separated by blank lines in Markdown
        class ParagraphTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if interface.html_mode?
              # Inside a table cell the surrounding <td> already provides the
              # block context, so a <p> wrapper just adds vertical margin —
              # and if the paragraph contains a block element (e.g. a list),
              # `<p><ul>…</ul></p>` is invalid per HTML5. Drop the wrapper.
              return content if interface.has_parent?(AST::TableCell)

              return "<p>#{content}</p>"
            end

            # Bracket with leading and trailing blank lines so adjacent
            # non-block content (raw text, inline elements) stays separated
            # from the paragraph. cleanup_markdown collapses any duplicate
            # newlines that result when neighbors are themselves block tags.
            "\n\n#{content}\n\n"
          end
        end
      end
    end
  end
end
