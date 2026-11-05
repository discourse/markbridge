# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering list items.
        #
        # An item does not indent itself. It renders its content at
        # column zero and hands it to the builder, which moves the whole
        # content right by the width of the marker. A nested list then
        # lands at the content column of the item that holds it, whatever
        # the nesting depth is.
        class ListItemTag < Tag
          # Ends a nested list in front of more content of the item.
          COMMENT = "<!---->"
          LIST_END = "\n<!---->"
          NEWLINE = 10
          SPACE = 32
          # Whitespace and the <br> the serializer writes for a line break
          # on a line that holds nothing else.
          TRAILING_BREAKS = /(?:[[:space:]]|<br>)+\z/
          private_constant :COMMENT, :LIST_END, :NEWLINE, :SPACE, :TRAILING_BREAKS

          def initialize
            @builder = Builders::ListItemBuilder.new
          end

          def render(element, interface)
            child_context = interface.with_parent(element)
            return render_html(element, interface, child_context) if interface.html_mode?

            content = render_content(element, interface, child_context)
            return "" if content.empty?

            parent_list = interface.find_parent(AST::List)
            @builder.build(content, marker: determine_marker(parent_list, interface))
          end

          private

          # @return [String]
          def render_html(element, interface, child_context)
            content = interface.render_children(element, context: child_context).strip
            content.empty? ? "" : "<li>#{content}</li>"
          end

          # A nested list is attached directly to the content in front of
          # it. A blank line there would make the whole list loose, and
          # CommonMark then wraps every item in a <p>. Blank lines inside
          # the output of a child are never touched.
          #
          # Text after a nested list would become a continuation line of
          # its last item, and a blank line in between would make the
          # list loose again. An empty HTML comment on a line of its own
          # ends the nested list without one; the whitespace between the
          # list and the text goes.
          # @return [String]
          def render_content(element, interface, child_context)
            after_list = false
            content =
              interface.render_children(element, context: child_context) do |buffer, child|
                if child.is_a?(AST::List)
                  tighten(buffer)
                  after_list = true
                elsif after_list && visible?(child)
                  end_list(buffer, before: child)
                  after_list = false
                end
              end
            content.strip
          end

          # The comment needs a line of its own: after it on the same line,
          # the text would be part of the HTML block. Text that starts with
          # a newline brings the line break itself. +before+ is the child
          # that comes next.
          def end_list(buffer, before:)
            buffer.sub!(TRAILING_BREAKS, "")
            buffer << LIST_END
            buffer << "\n" unless text_of(before)&.start_with?("\n")
          end

          # Whitespace and line breaks between a nested list and the text
          # after it do not count, the text does.
          def visible?(child)
            text = text_of(child)
            return text.match?(/[^[:space:]]/) if text

            !child.is_a?(AST::LineBreak)
          end

          # The text of a text child, as it is written to the output.
          def text_of(child)
            child.text if child.is_a?(AST::Text) || child.is_a?(AST::MarkdownText)
          end

          # Drops the blank lines in front of a nested list. A blank line
          # is what ends an HTML block, so a line in front that opens one
          # gets a different treatment: a line that starts a block of its
          # own (the line in front of it is blank, as with the `</div>` of
          # an aligned block) gets an empty comment in front, which makes
          # the line a comment block that ends on the same line; a line
          # inside a block an earlier line opened (the `</table>` of a
          # table) keeps the blank line, and the outer list is loose.
          def tighten(buffer)
            buffer.rstrip!
            # Byte offsets throughout: the content in front may hold
            # multi-byte characters.
            start = (buffer.byterindex("\n") || -1) + 1
            return unless HtmlBlock.opens?(buffer.byteslice(start..))

            if start.zero? || buffer.getbyte(start - 2) == NEWLINE
              # After the indentation of the line: a nested list has
              # indented its lines already.
              start += 1 while buffer.getbyte(start) == SPACE
              buffer.bytesplice(start, 0, COMMENT)
            else
              buffer << "\n"
            end
          end

          # @param parent_list [AST::List, nil]
          # @return [String]
          # The marker the renderer chose for the list (see
          # RenderingInterface#choose_list_marker), or the first one of
          # its kind for an item rendered without its list.
          def determine_marker(parent_list, interface)
            interface.list_marker(parent_list) || (parent_list&.ordered? ? "1. " : "- ")
          end
        end
      end
    end
  end
end
