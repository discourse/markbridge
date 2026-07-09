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

            return "<blockquote>#{content}</blockquote>" if interface.html_mode?

            # Build Discourse quote BBCode
            # Format: [quote="username, post:2, topic:456"]content[/quote]
            # (post: is the post number within the topic, topic: the topic id)
            body =
              if element.post_number && element.topic_id && element.username
                # Full Discourse quote with context
                "[quote=\"#{element.username}, post:#{element.post_number}, topic:#{element.topic_id}\"]\n#{content}\n[/quote]"
              elsif element.author || element.username
                # Name-only attribution; a bare post_id/user_id can't
                # produce a valid Discourse post reference.
                "[quote=\"#{element.author || element.username}\"]\n#{content}\n[/quote]"
              else
                # Plain quote rendered as Markdown blockquote
                content.split("\n").map { |line| "> #{line}" }.join("\n")
              end

            # Bracket with leading and trailing blank lines so consecutive
            # quotes don't merge and adjacent non-block content (raw text,
            # inline elements) starts a new paragraph against the quote.
            "\n\n#{body}\n\n"
          end
        end
      end
    end
  end
end
