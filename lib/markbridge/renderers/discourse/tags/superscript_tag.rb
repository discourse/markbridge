# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering superscript text as the HTML tag, which Markdown
        # has no form for. The tags are inline tokens so that the
        # serializer sees them as neighbors: a newline right after the
        # opening tag would leave it alone on its line, where it opens an
        # HTML block.
        class SuperscriptTag < Tag
          OPEN = Inline::Tokens.html("<sup>")
          CLOSE = Inline::Tokens.html("</sup>")
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
