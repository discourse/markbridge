# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Discourse's HTML sanitizer strips raw `<u>`, but `[u]…[/u]` is
        # cooked by the BBCode plugin into `<span class="bbcode-u">`. The
        # BBCode plugin runs on Markdown source, not on raw HTML inside an
        # HTML block, so in html_mode we emit the cooked form directly.
        #
        # Inside Markdown link text (`[text](url)`) the BBCode plugin also
        # does not re-cook nested BBCode, so `[[u]X[/u]](url)` would render
        # literally. Drop the wrapper when rendering under a link ancestor.
        class UnderlineTag < Tag
          def render(element, interface)
            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            return tokens if inside_link?(interface)

            tokens.unshift(Inline::Tokens.open(:u)) << Inline::Tokens.close(:u)
          end

          private

          def inside_link?(interface)
            interface.has_parent?(AST::Url) || interface.has_parent?(AST::Email)
          end
        end
      end
    end
  end
end
