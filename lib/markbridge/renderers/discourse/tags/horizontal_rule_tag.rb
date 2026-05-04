# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering horizontal rules
        class HorizontalRuleTag < Tag
          def render(_element, interface)
            interface.html_mode? ? "<hr>" : "\n\n---\n\n"
          end
        end
      end
    end
  end
end
