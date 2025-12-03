# frozen_string_literal: true

module Markbridge
  module AST
    # Represents colored text.
    # Note: Discourse doesn't support inline color by default,
    # but this preserves color information for migration/custom rendering.
    #
    # @example Colored text
    #   color = AST::Color.new(color: "red")
    #   color << AST::Text.new("Important text")
    class Color < Element
      # @return [String, nil] the color value (name or hex)
      attr_reader :color

      # Create a new Color element.
      #
      # @param color [String, nil] color name or hex code
      def initialize(color: nil)
        super()
        @color = color
      end
    end
  end
end
