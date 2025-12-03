# frozen_string_literal: true

module Markbridge
  module AST
    # Represents an attachment reference (image/file).
    #
    # @example Attachment by absolute ID
    #   attachment = AST::Attachment.new(id: "1234")
    #
    # @example Attachment by post-relative index with filename
    #   attachment = AST::Attachment.new(index: "0", filename: "image.jpg")
    #
    # @example Attachment with alt text
    #   attachment = AST::Attachment.new(id: "5678", alt: "diagram")
    class Attachment < Node
      # @return [String, Integer, nil] absolute attachment identifier
      attr_reader :id

      # @return [Integer, nil] post-relative index
      attr_reader :index

      # @return [String, nil] optional filename
      attr_reader :filename

      # @return [String, nil] optional alt text for the attachment
      attr_reader :alt

      # Create a new Attachment node.
      #
      # @param id [String, Integer, nil] absolute attachment identifier
      # @param index [Integer, nil] post-relative index
      # @param filename [String, nil] optional filename/caption
      # @param alt [String, nil] optional alt text
      def initialize(id: nil, index: nil, filename: nil, alt: nil)
        @id = id
        @index = index
        @filename = filename
        @alt = alt
      end
    end
  end
end
