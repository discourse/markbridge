# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering table rows (passthrough - renders children only)
        # The TableTag handles rows directly; this is a safety net for standalone rendering.
        class TableRowTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            interface.render_children(element, context: child_context)
          end
        end
      end
    end
  end
end
