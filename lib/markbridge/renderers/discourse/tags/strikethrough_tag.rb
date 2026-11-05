# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Strikethrough. The serializer writes the tildes, or an s tag
        # where a tilde at the edge of the content would make the marker
        # three tildes long.
        class StrikethroughTag < Tag
          def render(element, interface)
            tokens = interface.render_tokens(element, context: interface.with_parent(element))
            tokens.unshift(Inline::Tokens.open(:s)) << Inline::Tokens.close(:s)
          end
        end
      end
    end
  end
end
