# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a Discourse upload reference (image or file attachment).
    # Uses the upload:// URL scheme.
    #
    # @example Image upload
    #   upload = AST::Upload.new(
    #     sha1: "RBhXLF6381Te3mneJQNnnyNNt5",
    #     filename: "image.png",
    #     type: :image,
    #     alt: "My image",
    #     dimensions: "64x64"
    #   )
    #
    # @example File attachment
    #   upload = AST::Upload.new(
    #     sha1: "ppJp89TTiLOo6Vl4mAmo21MV28w",
    #     filename: "document.pdf",
    #     type: :attachment,
    #     size: "502.1 KB"
    #   )
    class Upload < Node
      # @return [String] the base62 SHA1 identifier from upload:// URL
      attr_reader :sha1

      # @return [String, nil] original filename
      attr_reader :filename

      # @return [Symbol] type of upload (:image or :attachment)
      attr_reader :type

      # @return [String, nil] alt text (for images)
      attr_reader :alt

      # @return [String, nil] dimensions string like "64x64" (for images)
      attr_reader :dimensions

      # @return [String, nil] file size string like "502.1 KB" (for attachments)
      attr_reader :size

      # @return [String, nil] the original raw Markdown
      attr_reader :raw

      # Create a new Upload node.
      #
      # @param sha1 [String] the base62 SHA1 identifier
      # @param filename [String, nil] original filename
      # @param type [Symbol] type of upload (:image or :attachment)
      # @param alt [String, nil] alt text
      # @param dimensions [String, nil] dimensions string
      # @param size [String, nil] file size string
      # @param raw [String, nil] the original raw Markdown
      def initialize(
        sha1:,
        filename: nil,
        type: :image,
        alt: nil,
        dimensions: nil,
        size: nil,
        raw: nil
      )
        @sha1 = sha1
        @filename = filename
        @type = type
        @alt = alt
        @dimensions = dimensions
        @size = size
        @raw = raw
      end
    end
  end
end
