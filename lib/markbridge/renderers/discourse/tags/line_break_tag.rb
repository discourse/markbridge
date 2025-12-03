# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering line breaks
        class LineBreakTag < Tag
          def render(_element, _interface)
            "\n"
          end
        end
      end
    end
  end
end
