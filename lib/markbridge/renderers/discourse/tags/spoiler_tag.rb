# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Renders a spoiler as the `[spoiler]…[/spoiler]` BBCode of the
        # spoiler-alert plugin. Discourse never reads an attribute of the
        # tag, so a title is written as text in front of the spoiler:
        # `title: [spoiler]…[/spoiler]`.
        #
        # A spoiler with +block+ set is written with the tags on lines of
        # their own, which Discourse reads as a block spoiler.
        #
        # With +bbcode: false+, for a site without the plugin, the content
        # is written as it is, so the hidden text shows.
        class SpoilerTag < Tag
          # @param bbcode [Boolean] write the BBCode of the plugin
          def initialize(bbcode: true)
            @bbcode = bbcode
          end

          def render(element, interface)
            child_context = interface.with_parent(element)
            content =
              interface.render_children(
                element,
                context: child_context,
                following: inline_close(element, interface),
              )

            # A spoiler with nothing to hide gets no tags, like the
            # serializer's markers: an empty [spoiler] shell would only
            # add noise to the output.
            return content unless content.match?(/[^[:space:]]/)

            return render_block(element, interface, content) if block?(element, interface)

            title = title_text(element, interface)
            # Discourse doesn't cook BBCode in the text of a link.
            return "#{title}#{content}" if !@bbcode || inside_link?(interface)
            return "#{title}#{render_html(content)}" if interface.html_mode?

            # `[spoiler]:x` at the start of a line reads as a link
            # reference definition, the backslash keeps the colon text.
            content = "\\#{content}" if content.start_with?(":")
            output = "#{title}[spoiler]#{Inline::Joins.close_url(content)}#{INLINE_CLOSE}"
            # A line that starts with `[spoiler]` and ends with `[/spoiler]`
            # is one block spoiler to Discourse, whatever stands between, so
            # two spoilers on it show their inner tags as text. A comment
            # after the second one ends the line with something else.
            output << Inline::Joins::BOUNDARY_COMMENT if after_spoiler?(element, interface)
            output
          end

          private

          INLINE_CLOSE = "[/spoiler]"
          private_constant :INLINE_CLOSE

          # The closing tag when it follows the content on the same line.
          # A bare URL in front of it would take it into the link.
          def inline_close(element, interface)
            return if !@bbcode || element.block || interface.html_mode? || inside_link?(interface)

            INLINE_CLOSE
          end

          # A block spoiler in the text of a link is written like an
          # inline one, as its content. The normalizer moves a block out of
          # a link, so this is for a tree that was not normalized.
          def block?(element, interface)
            element.block && !inside_link?(interface)
          end

          # `[spoiler]` and `[/spoiler]` on lines of their own are a block
          # spoiler to Discourse, with blocks inside. The title is a
          # paragraph in front of it. Without the plugin the content is a
          # block of its own too.
          def render_block(element, interface, content)
            title = title_text(element, interface)&.rstrip
            return "#{title}<div class=\"spoiler\">#{content}</div>" if interface.html_mode?

            content = content.gsub(/\A\n+|\n+\z/, "")
            content = "[spoiler]\n#{content}\n[/spoiler]" if @bbcode
            title ? "\n\n#{title}\n\n#{content}\n\n" : "\n\n#{content}\n\n"
          end

          # Whether a spoiler stands in front of +element+ on the same line,
          # with anything inline between. A text that has something visible
          # after its last newline starts the line, so the search ends
          # there. A spoiler with a title starts its line with the title,
          # not with `[spoiler]`, and is looked over like text.
          def after_spoiler?(element, interface)
            offset = -1
            loop do
              node = interface.sibling(element, offset:)
              return false if node.nil?
              return true if node.is_a?(AST::Spoiler) && !titled?(node)
              return false if node.is_a?(AST::Text) && starts_line?(node.text)

              offset -= 1
            end
          end

          def starts_line?(text)
            text.include?("\n") && text.rpartition("\n").last.match?(/[^[:space:]]/)
          end

          def titled?(element)
            element.title.to_s.match?(/[^[:space:]]/)
          end

          # The title with a colon and a space after it, escaped like any
          # text, or nil without a title.
          def title_text(element, interface)
            return unless titled?(element)

            "#{interface.render_node(AST::Text.new(element.title.strip))}: "
          end

          # The inline form Discourse cooks the BBCode to. A <details>
          # would be a block, which an HTML parser moves out of the
          # emphasis around it.
          def render_html(content)
            %(<span class="spoiler">#{content}</span>)
          end

          def inside_link?(interface)
            interface.has_parent?(AST::Url) || interface.has_parent?(AST::Email)
          end
        end
      end
    end
  end
end
