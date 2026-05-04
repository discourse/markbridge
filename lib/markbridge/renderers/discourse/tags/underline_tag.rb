# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering underline text.
        # Discourse Markdown doesn't support <u> HTML but does support [u]
        # via its BBCode extension, which cooks to <span class="bbcode-u">.
        # Inside an HTML block CommonMark passes content through raw, so the
        # BBCode plugin never runs and [u]…[/u] would render literally —
        # emit the cooked form directly in html_mode.
        class UnderlineTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if interface.html_mode?
              %(<span class="bbcode-u">#{content}</span>)
            else
              "[u]#{content}[/u]"
            end
          end
        end
      end
    end
  end
end
