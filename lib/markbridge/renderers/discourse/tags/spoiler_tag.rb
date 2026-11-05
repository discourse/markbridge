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

            # A spoiler with nothing to hide renders to nothing — an empty
            # [spoiler] shell would only add noise to the output.
            return "" if content.empty?

            return render_html(element.title, content) if interface.html_mode?

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

          def render_html(title, content)
            summary = "<summary>#{title ? HtmlEscaper.escape(title) : "Spoiler"}</summary>"
            "<details>#{summary}#{content}</details>"
          end
        end
      end
    end
  end
end
