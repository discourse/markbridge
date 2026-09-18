# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class HeadingTag < Tag
          # A run of # at the end of an ATX heading, after whitespace, is
          # the optional closing sequence and disappears when cooked.
          CLOSING_SEQUENCE = /(?<=[ \t])#+[ \t]*\z/
          private_constant :CLOSING_SEQUENCE

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if interface.html_mode?
              level = element.level.clamp(1, 6)
              return "<h#{level}>#{content}</h#{level}>"
            end

            prefix = "#" * element.level

            "\n\n#{prefix} #{keep_trailing_hashes(content)}\n\n"
          end

          private

          # A backslash in front of the run keeps it as text. The escaper
          # does not do this, it only knows about # at the start of a line.
          def keep_trailing_hashes(content)
            return content unless content.end_with?("#")

            content.sub(CLOSING_SEQUENCE) { |run| "\\#{run}" }
          end
        end
      end
    end
  end
end
