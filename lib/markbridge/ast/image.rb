# frozen_string_literal: true

module Markbridge
  module AST
    # Represents an image element.
    #
    # @example Basic image
    #   image = AST::Image.new(src: "https://example.com/img.png")
    #
    # @example Image with dimensions
    #   image = AST::Image.new(src: "https://example.com/img.png", width: 100, height: 100)
    #
    # @example Image with alternative text
    #   image = AST::Image.new(src: "https://example.com/img.png", alt: "a cat")
    class Image < Element
      # @return [String, nil] the image source URL
      attr_reader :src

      # @return [Integer, nil] the image width
      attr_reader :width

      # @return [Integer, nil] the image height
      attr_reader :height

      # @return [String, nil] the alternative text
      attr_reader :alt

      # Create a new Image element.
      #
      # @param src [String, nil] the image source URL
      # @param width [Integer, nil] the image width
      # @param height [Integer, nil] the image height
      # @param alt [String, nil] the alternative text
      def initialize(src: nil, width: nil, height: nil, alt: nil)
        super()
        @src = src
        @width = width
        @height = height
        @alt = alt
      end
    end
  end
end
