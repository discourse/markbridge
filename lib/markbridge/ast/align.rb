# frozen_string_literal: true

module Markbridge
  module AST
    # Represents aligned text (left, center, right, justify).
    # Note: Discourse has limited support for alignment.
    #
    # @example Center-aligned text
    #   align = AST::Align.new(alignment: "center")
    #   align << AST::Text.new("Centered text")
    class Align < Element
      # @return [String, nil] the alignment value (left, center, right, justify)
      attr_reader :alignment

      # Create a new Align element.
      #
      # @param alignment [String, nil] alignment value
      def initialize(alignment: nil)
        super()
        @alignment = alignment
      end
    end
  end
end
