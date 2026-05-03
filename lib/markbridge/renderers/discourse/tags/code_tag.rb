# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        class CodeTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            if interface.block_context?(element)
              render_block(content, element.language)
            elsif interface.html_mode?
              "<code>#{content}</code>"
            else
              render_inline(content)
            end
          end

          private

          def render_inline(content)
            "`#{content}`"
          end

          # Trailing blank line keeps an adjacent fence on the next block from
          # being parsed as a continuation of this one.
          def render_block(content, language)
            fence = calculate_fence(content)
            "#{fence}#{language}\n#{content}\n#{fence}\n\n"
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
