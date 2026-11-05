# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Renders a spoiler as the `[spoiler]…[/spoiler]` BBCode of the
        # spoiler-alert plugin. Discourse never reads an attribute of the
        # tag, so a title is written as text in front of the spoiler:
        # `title: [spoiler]…[/spoiler]`.
        class SpoilerTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            # A spoiler with nothing to hide gets no tags, like the
            # serializer's markers: an empty [spoiler] shell would only
            # add noise to the output.
            return content unless content.match?(/[^[:space:]]/)

            title = title_text(element, interface, child_context)
            return "#{title}#{render_html(content)}" if interface.html_mode?

            # `[spoiler]:x` at the start of a line reads as a link
            # reference definition, the backslash keeps the colon text.
            content = "\\#{content}" if content.start_with?(":")
            "#{title}[spoiler]#{content}[/spoiler]"
          end

          private

          # The title with a colon and a space after it, escaped like any
          # text, or an empty String without a title.
          def title_text(element, interface, context)
            title = element.title.to_s
            return "" unless title.match?(/[^[:space:]]/)

            text = interface.render_node(AST::Text.new(title.strip), context:)
            "#{text}: "
          end

          # The inline form Discourse cooks the BBCode to. A <details>
          # would be a block, which an HTML parser moves out of the link
          # or the emphasis around it.
          def render_html(content)
            %(<span class="spoiler">#{content}</span>)
          end
        end
      end
    end
  end
end
