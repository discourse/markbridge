# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering spoilers
        # Renders to Discourse BBCode spoiler format
        class SpoilerTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if element.title
              "[spoiler=#{element.title}]#{content}[/spoiler]"
            else
              "[spoiler]#{content}[/spoiler]"
            end
          end
        end
      end
    end
  end
end
