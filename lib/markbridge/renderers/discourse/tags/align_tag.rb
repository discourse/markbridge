# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Alignment is constrained to a known CSS keyword set so the inline
        # `style` is not a freeform CSS injection surface — anything outside
        # that set falls through to bare content.
        class AlignTag < Tag
          ALLOWED_ALIGNMENTS = Set["left", "right", "center", "justify"].freeze
          private_constant :ALLOWED_ALIGNMENTS

          def html_mode_aware? = true

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            return content unless ALLOWED_ALIGNMENTS.include?(element.alignment)

            wrapper = %(<div style="text-align: #{element.alignment}">#{content}</div>)
            # Skip the trailing blank line in html_mode: a blank line would
            # terminate the surrounding HTML block (e.g. an enclosing <table>).
            interface.html_mode? ? wrapper : "#{wrapper}\n\n"
          end
        end
      end
    end
  end
end
