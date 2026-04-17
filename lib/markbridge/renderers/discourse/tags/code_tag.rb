# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering code
        class CodeTag < Tag
          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            # Determine if inline or block based on context
            if interface.block_context?(element)
              render_block(content, element.language)
            else
              render_inline(content)
            end
          end

          private

          def render_inline(content)
            "`#{content}`"
          end

          def render_block(content, language)
            fence = calculate_fence(content)

            "#{fence}#{language}\n#{content}\n#{fence}"
          end

          def calculate_fence(content)
            # Need fence longer than any sequence in content (minimum 3)
            required_backticks = (content.scan(/`+/).map { |run| run.length + 1 } + [3]).max
            required_tildes = (content.scan(/~+/).map { |run| run.length + 1 } + [3]).max

            # Choose whichever requires fewer characters
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
