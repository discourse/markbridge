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
            # Choose fence style based on content
            fence = content.include?("`") ? "~~~" : "```"
            lang = language || ""

            "#{fence}#{lang}\n#{content}\n#{fence}"
          end
        end
      end
    end
  end
end
