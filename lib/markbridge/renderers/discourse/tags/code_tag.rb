# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class CodeTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            # An empty element renders to nothing — a bare `` pair or an
            # empty fence would only add noise to the output.
            return "" if content.empty?

            if interface.block_context?(element)
              if interface.html_mode?
                render_html_block(content, element.language)
              else
                render_block(content, element.language)
              end
            elsif interface.html_mode?
              "<code>#{content}</code>"
            else
              render_inline(content)
            end
          end

          private

          # The delimiter is one backtick longer than the longest backtick
          # run in the content. A space on each side keeps a backtick at
          # the edge of the content away from the delimiter. Content that
          # starts and ends with a space gets the same padding, because
          # CommonMark strips one space from each end of such a span.
          def render_inline(content)
            longest_run = content.scan(/`+/).map(&:length).max || 0
            delimiter = "`" * (longest_run + 1)
            padding = needs_padding?(content) ? " " : ""

            "#{delimiter}#{padding}#{content}#{padding}#{delimiter}"
          end

          def needs_padding?(content)
            return true if content.start_with?("`") || content.end_with?("`")

            content.start_with?(" ") && content.end_with?(" ") && !content.strip.empty?
          end

          # Leading and trailing blank lines: the trailing one keeps an
          # adjacent fence on the next block from being parsed as a
          # continuation of this one; the leading one separates the fence
          # from prior raw text or inline content.
          def render_block(content, language)
            fence = calculate_fence(content)
            # The newline in front of the closing fence is part of the fence
            # syntax, not of the code. A content that already ends with a
            # newline (as <pre> content from HTML usually does) would
            # otherwise cook with a blank line too many at the end.
            "\n\n#{fence}#{language}\n#{content.chomp}\n#{fence}\n\n"
          end

          def render_html_block(content, language)
            class_attr = %( class="language-#{HtmlEscaper.escape(language)}") if language
            "<pre><code#{class_attr}>#{content}</code></pre>"
          end

          def calculate_fence(content)
            max_backticks = content.scan(/`+/).map(&:length).max || 0
            max_tildes = content.scan(/~+/).map(&:length).max || 0

            required_backticks = [3, max_backticks + 1].max
            required_tildes = [3, max_tildes + 1].max

            if required_backticks <= required_tildes
              "`" * required_backticks
            else
              "~" * required_tildes
            end
          end
        end
      end
    end
  end
end
