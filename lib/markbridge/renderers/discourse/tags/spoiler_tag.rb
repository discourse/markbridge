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
        # With +bbcode: false+, for a site without the plugin, the content
        # is written as it is, so the hidden text shows.
        class SpoilerTag < Tag
          # @param bbcode [Boolean] write the BBCode of the plugin
          def initialize(bbcode: true)
            @bbcode = bbcode
          end

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            # A spoiler with nothing to hide gets no tags, like the
            # serializer's markers: an empty [spoiler] shell would only
            # add noise to the output.
            return content unless content.match?(/[^[:space:]]/)

            title = title_text(element, interface)
            # Discourse doesn't cook BBCode in the text of a link.
            return "#{title}#{content}" if !@bbcode || inside_link?(interface)
            return "#{title}#{render_html(content)}" if interface.html_mode?

            # `[spoiler]:x` at the start of a line reads as a link
            # reference definition, the backslash keeps the colon text.
            content = "\\#{content}" if content.start_with?(":")
            output = "#{title}[spoiler]#{content}[/spoiler]"
            # A line that starts with `[spoiler]` and ends with `[/spoiler]`
            # is one block spoiler to Discourse, whatever stands between, so
            # two spoilers on it show their inner tags as text. A comment
            # after the second one ends the line with something else.
            output << Inline::Joins::BOUNDARY_COMMENT if after_spoiler?(element, interface)
            output
          end

          private

          # Whether a spoiler stands in front of +element+, with nothing but
          # whitespace between.
          def after_spoiler?(element, interface)
            offset = -1
            loop do
              node = interface.sibling(element, offset:)
              return true if node.is_a?(AST::Spoiler)
              return false unless node.is_a?(AST::Text) && node.text.match?(/\A[[:space:]]*\z/)

              offset -= 1
            end
          end

          # The title with a colon and a space after it, escaped like any
          # text, or nil without a title.
          def title_text(element, interface)
            title = element.title.to_s
            return unless title.match?(/[^[:space:]]/)

            "#{interface.render_node(AST::Text.new(title.strip))}: "
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
