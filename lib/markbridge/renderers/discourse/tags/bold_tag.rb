# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Strong emphasis. The serializer writes the markers, or the HTML
        # tags where the markers would not work.
        class BoldTag < Tag
          def render(element, interface)
            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            tokens.unshift(Inline::Tokens.open(:strong)) << Inline::Tokens.close(:strong)
          end
        end
      end
    end
  end
end
