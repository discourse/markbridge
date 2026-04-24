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

            # nil language interpolates as empty string. Blank line keeps
            # adjacent fences from merging.
            "#{fence}#{language}\n#{content}\n#{fence}\n\n"
          end

          def calculate_fence(content)
            # Find longest sequence of backticks and tildes
            max_backticks = content.scan(/`+/).map(&:length).max || 0
            max_tildes = content.scan(/~+/).map(&:length).max || 0

            # Need fence longer than any sequence in content (minimum 3)
            required_backticks = [3, max_backticks + 1].max
            required_tildes = [3, max_tildes + 1].max

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
