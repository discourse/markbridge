# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Cleans up the raw Markdown produced by the Renderer:
      #
      # 1. collapses runs of 3+ newlines down to two,
      # 2. clears whitespace-only lines,
      # 3. trims leading/trailing whitespace from the whole document.
      #
      # Subclass to customize. The +call+ method is the entry point.
      class Postprocessor
        # @param text [String]
        # @return [String]
        def call(text)
          text
            .gsub(/\n{3,}/, "\n\n") # Max 2 consecutive newlines
            .gsub(/^[ \t]+$/, "") # Remove whitespace-only lines
            .strip # Trim leading/trailing whitespace
        end

        DEFAULT = new
      end
    end
  end
end
