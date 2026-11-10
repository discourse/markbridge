# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering paragraphs
        # Paragraphs are separated by blank lines in Markdown
        class ParagraphTag < Tag
          # Spaces and tabs at the start of the paragraph. Not a no-break
          # space: the escaper writes one where it wants indentation kept.
          LEADING_BLANKS = /\A[ \t]+/
          VISIBLE = /[^[:space:]]/
          private_constant :LEADING_BLANKS, :VISIBLE

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if interface.html_mode?
              # Also inside a table cell: without the <p> the paragraph
              # runs into the text next to it. A block inside the
              # paragraph closes the <p> early in the HTML parser, which
              # is what the Markdown form does as well. A paragraph with
              # nothing visible is nothing, like in Markdown: an empty <p>
              # would keep a list item or a list around it alive.
              return content.match?(VISIBLE) ? "<p>#{content}</p>" : ""
            end

            # Bracket with leading and trailing blank lines so adjacent
            # non-block content (raw text, inline elements) stays separated
            # from the paragraph. cleanup_markdown collapses any duplicate
            # newlines that result when neighbours are themselves block tags.
            # Spaces at the start go: CommonMark drops up to three of them
            # anyway, and after a list they would make the paragraph part
            # of the last item.
            content = content.sub(LEADING_BLANKS, "") if content.match?(LEADING_BLANKS)
            "\n\n#{content}\n\n"
          end
        end
      end
    end
  end
end
