# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering strikethrough text
        class StrikethroughTag < Tag
          TILDE_AT_EDGE = /\A[[:space:]]*~|~[[:space:]]*\z/
          private_constant :TILDE_AT_EDGE

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)
            # A tilde at the edge of the content would make the marker
            # three tildes long, which does not close (or opens a fence
            # at the start of a line). wrap_inline falls back to the same
            # tag for content with `~~` in it.
            return "<s>#{content}</s>" if interface.html_mode? || content.match?(TILDE_AT_EDGE)

            interface.wrap_inline(content, "~~")
          end
        end
      end
    end
  end
end
