# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Emphasis. The serializer writes the markers, or the HTML tags
        # where the markers would not work.
        class ItalicTag < Tag
          def render(element, interface)
            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            tokens.unshift(Inline::Tokens.open(:em)) << Inline::Tokens.close(:em)
          end
        end
      end
    end
  end
end
