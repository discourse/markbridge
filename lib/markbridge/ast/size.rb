# frozen_string_literal: true

module Markbridge
  module AST
    # Represents sized text.
    # Note: Discourse doesn't support inline size changes by default,
    # but this preserves size information for migration/custom rendering.
    #
    # @example Sized text
    #   size = AST::Size.new(size: "20")
    #   size << AST::Text.new("Big text")
    class Size < Element
      # @return [String, nil] the font size value
      attr_reader :size

      # Create a new Size element.
      #
      # @param size [String, nil] font size value
      def initialize(size: nil)
        super()
        @size = size
      end
    end
  end
end
