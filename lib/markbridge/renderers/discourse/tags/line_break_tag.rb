# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering line breaks. A heading is one line, so a break
        # in a heading is written as <br>, which markdown-it keeps inline.
        class LineBreakTag < Tag
          def render(_element, interface)
            interface.html_mode? || interface.has_parent?(AST::Heading) ? "<br>" : "\n"
          end
        end
      end
    end
  end
end
