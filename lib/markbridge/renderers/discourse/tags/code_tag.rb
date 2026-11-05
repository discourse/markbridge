# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class CodeTag < Tag
          BACKTICKS = /`+/
          TILDES = /~+/
          private_constant :BACKTICKS, :TILDES

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            # An empty element renders to nothing — a bare `` pair or an
            # empty fence would only add noise to the output. An empty code
            # block is still a block, so a blank line keeps the text in
            # front and after it apart, except in an HTML block, which a
            # blank line would end.
            if content.empty?
              return interface.block_context?(element) && !interface.html_mode? ? "\n\n" : ""
            end

            if interface.block_context?(element)
              if interface.html_mode?
                render_html_block(content, element.language)
              else
                render_block(content, element.language)
              end
            elsif interface.html_mode?
              "<code>#{content}</code>"
            else
              # A pipe in a code span still splits the cell of a Markdown
              # table, the escaped pipe does not and reads back as a pipe.
              content = content.gsub("|", "\\|") if interface.has_parent?(AST::TableCell)
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
            delimiter = "`" * (longest_run(content, BACKTICKS) + 1)
            padding = " " if needs_padding?(content)

            "#{delimiter}#{padding}#{content}#{padding}#{delimiter}"
          end

          def needs_padding?(content)
            return true if content.start_with?("`") || content.end_with?("`")

            # A span of spaces only is not stripped by CommonMark, so it
            # needs no padding.
            content.start_with?(" ") && content.end_with?(" ") &&
              content.count(" ") < content.length
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

          # A blank line in the code would end the HTML block around it.
          def render_html_block(content, language)
            class_attr = %( class="language-#{HtmlEscaper.escape(language)}") if language
            "<pre><code#{class_attr}>#{HtmlBlock.without_blank_lines(content)}</code></pre>"
          end

          def calculate_fence(content)
            required_backticks = [3, longest_run(content, BACKTICKS) + 1].max
            required_tildes = [3, longest_run(content, TILDES) + 1].max

            if required_backticks <= required_tildes
              "`" * required_backticks
            else
              "~" * required_tildes
            end
          end

          # The length of the longest run that +pattern+ finds in
          # +content+, 0 when there is none. A delimiter or a fence has to
          # be longer than that.
          def longest_run(content, pattern)
            content.scan(pattern).map(&:length).max || 0
          end
        end
      end
    end
  end
end
