# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Tags
        # Tag for rendering images
        # Renders to Markdown image syntax with optional Discourse sizing
        class ImageTag < Tag
          def render(element, interface)
            src = element.src || ""
            width = element.width
            height = element.height

            # Build Discourse image syntax with dimensions
            # Format: ![alt|WIDTHxHEIGHT](url) or ![alt|WIDTH](url)
            if width && height
              "![|#{width}x#{height}](#{src})"
            elsif width
              "![|#{width}](#{src})"
            else
              "![](#{src})"
            end
          end
        end
      end
    end
  end
end
