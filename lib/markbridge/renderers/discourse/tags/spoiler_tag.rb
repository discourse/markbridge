# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering spoilers
        # Renders to Discourse BBCode spoiler format
        class SpoilerTag < Tag
          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            return render_html(element.title, content) if interface.html_mode?

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
