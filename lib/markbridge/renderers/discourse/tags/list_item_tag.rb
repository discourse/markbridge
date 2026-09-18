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
          def initialize
            @builder = Builders::ListItemBuilder.new
          end

          def render(element, interface)
            child_context = interface.with_parent(element)
            return render_html(element, interface, child_context) if interface.html_mode?

            content = render_content(element, interface, child_context)
            return "" if content.empty?

            parent_list = interface.find_parent(AST::List)
            @builder.build(content, marker: determine_marker(parent_list))
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
          # @return [String]
          def render_content(element, interface, child_context)
            content =
              interface.render_children(element, context: child_context) do |buffer, child|
                tighten(buffer) if child.is_a?(AST::List)
              end
            content.strip
          end

          # Drops the blank lines in front of a nested list, but keeps one
          # when the line before it opens an HTML block (for example a
          # `</table>`), because only a blank line ends such a block.
          def tighten(buffer)
            buffer.rstrip!
            last_line = buffer[(buffer.rindex("\n") || -1) + 1..]
            buffer << "\n" if HtmlBlock.opens?(last_line)
          end

          # @param parent_list [AST::List, nil]
          # @return [String]
          def determine_marker(parent_list)
            parent_list&.ordered? ? "1. " : "- "
          end
        end
      end
    end
  end
end
