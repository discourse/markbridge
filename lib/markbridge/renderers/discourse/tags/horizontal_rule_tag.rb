# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering horizontal rules
        class HorizontalRuleTag < Tag
          def render(_element, _interface)
            "\n\n---\n\n"
          end
        end
      end
    end
  end
end
