# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering quotes
        # Renders to Discourse BBCode quote format to preserve attribution
        class QuoteTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            # Build Discourse quote BBCode
            # Format: [quote="username, post:123, topic:456"]content[/quote]
            body =
              if element.post && element.topic && element.username
                # Full Discourse quote with context
                "[quote=\"#{element.username}, post:#{element.post}, topic:#{element.topic}\"]\n#{content}\n[/quote]"
              elsif element.author
                # Quote with author attribution only
                "[quote=\"#{element.author}\"]\n#{content}\n[/quote]"
              else
                # Plain quote rendered as Markdown blockquote
                content.split("\n").map { |line| "> #{line}" }.join("\n")
              end

            # Trailing blank line so consecutive quotes don't merge and
            # following content starts a new paragraph.
            "#{body}\n\n"
          end
        end
      end
    end
  end
end
