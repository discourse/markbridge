# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering highlighted text as the HTML tag, which Markdown has no
        # form for and Discourse keeps. The tags are inline tokens so that
        # the serializer sees them as neighbors: a newline right after the
        # opening tag would leave it alone on its line, where it opens an
        # HTML block.
        class HighlightTag < Tag
          OPEN = Inline::Tokens.html("<mark>")
          CLOSE = Inline::Tokens.html("</mark>")
          private_constant :OPEN, :CLOSE

          def render(element, interface)
            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            tokens.unshift(OPEN) << CLOSE
          end
        end
      end
    end
  end
end
