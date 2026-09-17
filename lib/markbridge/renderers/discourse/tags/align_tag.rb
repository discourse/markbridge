# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Discourse's HTML sanitizer allows the (HTML5-deprecated) `align`
        # attribute on `<div>` but strips inline `style`, so we emit the
        # legacy form. Alignment is constrained to a known keyword set
        # for defense in depth — anything outside the set falls through
        # to bare content rather than getting interpolated into the
        # attribute.
        class AlignTag < Tag
          ALLOWED_ALIGNMENTS = Set["left", "right", "center", "justify"].freeze
          BLANK_EDGES = /\A(?:[ \t]*\n)+|(?:\n[ \t]*)+\z/
          private_constant :ALLOWED_ALIGNMENTS, :BLANK_EDGES

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            return content unless ALLOWED_ALIGNMENTS.include?(element.alignment)

            return html_block_form(element, content) if interface.html_mode?

            # Keeps consecutive aligned blocks from merging.
            "\n\n#{markdown_island_form(element, content)}\n\n"
          end

          private

          # Children already render as raw HTML here, and a blank line
          # would terminate the enclosing block (e.g. a <table>).
          def html_block_form(element, content)
            %(<div align="#{element.alignment}">#{content}</div>)
          end

          # A `<div>` opens an HTML block (CommonMark §4.6), and Markdown
          # inside one is only parsed across blank lines. Without them a
          # link in the content shows up as its own source text. The blank
          # lines do mean CommonMark wraps the content in a `<p>`, so
          # inline content picks up a paragraph margin.
          def markdown_island_form(element, content)
            open_tag = %(<div align="#{element.alignment}">)
            return "#{open_tag}</div>" if content.match?(/\A\s*\z/)

            "#{open_tag}\n\n#{content.gsub(BLANK_EDGES, "")}\n\n</div>"
          end
        end
      end
    end
  end
end
