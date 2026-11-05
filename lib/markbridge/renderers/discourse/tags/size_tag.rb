# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering sized text as a span with a style, which needs
        # HTML to be enabled; Discourse has no Markdown for it. The tags
        # are inline tokens, see SuperscriptTag. Without a size the
        # content stands alone.
        class SizeTag < Tag
          CLOSE = Inline::Tokens.html("</span>")
          private_constant :CLOSE

          def render(element, interface)
            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            return tokens unless element.size

            open = Inline::Tokens.html(%(<span style="font-size: #{element.size}px">))
            tokens.unshift(open) << CLOSE
          end
        end
      end
    end
  end
end
