# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering horizontal rules
        class HorizontalRuleTag < Tag
          def render(_element, interface)
            return "<hr>" if interface.html_mode?

            # `- ---` is a thematic break that ends the list, because the
            # marker and the dashes together are one run of dashes and
            # spaces. `- * * *` is a list item that holds a thematic break
            # (CommonMark example 61), so inside a list item stars are used.
            interface.has_parent?(AST::ListItem) ? "\n\n* * *\n\n" : "\n\n---\n\n"
          end
        end
      end
    end
  end
end
