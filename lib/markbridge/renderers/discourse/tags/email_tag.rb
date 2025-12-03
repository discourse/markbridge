# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering email links
        class EmailTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            text = interface.render_children(element, context: child_context)
            address = element.address

            if address
              "[#{text}](mailto:#{address})"
            else
              text
            end
          end
        end
      end
    end
  end
end
