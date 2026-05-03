# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering paragraphs
        # Paragraphs are separated by blank lines in Markdown
        class ParagraphTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            return "<p>#{content}</p>" if interface.html_mode?

            # Paragraph followed by blank line (two newlines)
            "#{content}\n\n"
          end
        end
      end
    end
  end
end
