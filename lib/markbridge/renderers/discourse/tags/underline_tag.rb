# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering underline text.
        # Discourse Markdown doesn't support <u> HTML but does support [u]
        # via its BBCode extension, so we emit the BBCode form.
        class UnderlineTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            "[u]#{content}[/u]"
          end
        end
      end
    end
  end
end
