# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Images: an image token. The serializer writes
        # `![alt|WIDTHxHEIGHT](url)` or `![alt](url)`
        # with the alt text escaped like a link label, and <img> in an
        # HTML block.
        class ImageTag < Tag
          def render(element, _interface)
            [
              Inline::Tokens.image(
                src: element.src,
                alt: element.alt,
                width: element.width,
                height: element.height,
              ),
            ]
          end
        end
      end
    end
  end
end
