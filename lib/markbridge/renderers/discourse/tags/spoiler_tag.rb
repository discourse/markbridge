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

            # A spoiler with nothing to hide gets no tags, like the
            # serializer's markers: an empty [spoiler] shell would only
            # add noise to the output.
            return content unless content.match?(/[^[:space:]]/)
            return render_html(content) if interface.html_mode?

            # `[spoiler]:x` at the start of a line reads as a link
            # reference definition, the backslash keeps the colon text.
            content = "\\#{content}" if content.start_with?(":")
            if element.title
              "[spoiler=#{element.title}]#{content}[/spoiler]"
            else
              "[spoiler]#{content}[/spoiler]"
            end
          end

          private

          # The inline form Discourse cooks the BBCode to. A <details>
          # would be a block, which an HTML parser moves out of the link
          # or the emphasis around it. The title has no place in it.
          def render_html(content)
            %(<span class="spoiler">#{content}</span>)
          end
        end
      end
    end
  end
end
