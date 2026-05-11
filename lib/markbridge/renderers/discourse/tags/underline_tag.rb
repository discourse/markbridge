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
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            return content unless content.match?(/[^[:space:]]/)

            if interface.html_mode?
              %(<span class="bbcode-u">#{content}</span>)
            elsif inside_link?(interface)
              content
            else
              "[u]#{content}[/u]"
            end
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
