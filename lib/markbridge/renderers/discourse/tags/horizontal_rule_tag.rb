# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering horizontal rules
        class HorizontalRuleTag < Tag
          def render(_element, interface)
            return "<hr>" if interface.html_mode?

            list = interface.find_parent(AST::List)
            return "\n\n---\n\n" unless list

            # `- ---` is a thematic break that ends the list, because the
            # marker and the dashes together are one run of dashes and
            # spaces. `- * * *` is a list item that holds a thematic break
            # (CommonMark example 61), so inside a list item the rule is
            # written with the character the list's marker does not use;
            # `* * * *` would be the rule alone again.
            interface.list_marker(list)&.start_with?("*") ? "\n\n- - -\n\n" : "\n\n* * *\n\n"
          end
        end
      end
    end
  end
end
