# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class HeadingTag < Tag
          # A run of # at the end of an ATX heading, after whitespace, is
          # the optional closing sequence and disappears when cooked. The
          # space after the prefix counts, so a run that is the whole
          # content is one too.
          CLOSING_SEQUENCE = /(?:\A|(?<=[ \t]))#+[ \t]*\z/
          # A heading is one line. A newline in its content, from a text
          # node, is a soft break and becomes a space; LineBreakTag writes
          # a hard break in a heading as <br>.
          LINE_BREAK = /[ \t]*\n[ \t]*/
          private_constant :CLOSING_SEQUENCE, :LINE_BREAK

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if interface.html_mode?
              level = element.level.clamp(1, 6)
              return "<h#{level}>#{content}</h#{level}>"
            end

            prefix = "#" * element.level

            "\n\n#{prefix} #{keep_trailing_hashes(content.gsub(LINE_BREAK, " "))}\n\n"
          end

          private

          # A backslash in front of the run keeps it as text. The escaper
          # does not do this, it only knows about # at the start of a line.
          def keep_trailing_hashes(content)
            content.sub(CLOSING_SEQUENCE) { |run| "\\#{run}" }
          end
        end
      end
    end
  end
end
