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
            # An empty quote shows nothing, but it is still a block: the
            # blank line keeps the text in front and after it apart. In an
            # HTML block a blank line would end the block.
            return interface.html_mode? ? "" : "\n\n" if content.empty?
            return "<blockquote>#{content}</blockquote>" if interface.html_mode?

            # A block at the start or the end brings its own blank lines.
            content = content.gsub(/\A\n+|\n+\z/, "")

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
              elsif nests_attributed_quote?(element)
                # Discourse doesn't render a [quote="…"] inside a Markdown
                # blockquote, so the outer quote is BBCode too.
                "[quote]\n#{content}\n[/quote]"
              else
                # Plain quote rendered as Markdown blockquote
                blockquote(content)
              end

            # Bracket with leading and trailing blank lines so consecutive
            # quotes don't merge and adjacent non-block content (raw text,
            # inline elements) starts a new paragraph against the quote.
            "\n\n#{body}\n\n"
          end

          private

          # Two blocks in the content have more than one blank line
          # between them, which the postprocessor collapses at the end.
          # With a `>` in front of every line it does not see them as
          # blank lines, so they are collapsed here.
          def blockquote(content)
            content = Postprocessor::DEFAULT.collapse_blank_lines(content)
            content.split("\n").map { |line| "> #{line}" }.join("\n")
          end

          # @param element [AST::Element]
          # @return [Boolean] whether a quote that renders as [quote="…"]
          #   is somewhere inside +element+
          def nests_attributed_quote?(element)
            element.children.any? do |child|
              child.is_a?(AST::Element) &&
                (
                  (child.is_a?(AST::Quote) && (child.author || child.username)) ||
                    nests_attributed_quote?(child)
                )
            end
          end
        end
      end
    end
  end
end
