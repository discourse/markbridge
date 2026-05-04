# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Discourse's HTML sanitizer allows the (HTML5-deprecated) `align`
        # attribute on `<div>` but strips inline `style`, so we emit the
        # legacy form. Alignment is constrained to a known keyword set
        # for defense in depth — anything outside the set falls through
        # to bare content rather than getting interpolated into the
        # attribute.
        class AlignTag < Tag
          ALLOWED_ALIGNMENTS = Set["left", "right", "center", "justify"].freeze
          private_constant :ALLOWED_ALIGNMENTS

          def render(element, interface)
            child_context = interface.with_parent(element)
            content = interface.render_children(element, context: child_context)

            return content unless ALLOWED_ALIGNMENTS.include?(element.alignment)

            wrapper = %(<div align="#{element.alignment}">#{content}</div>)
            # Skip the trailing blank line in html_mode: a blank line would
            # terminate the surrounding HTML block (e.g. an enclosing <table>).
            interface.html_mode? ? wrapper : "#{wrapper}\n\n"
          end
        end
      end
    end
  end
end
