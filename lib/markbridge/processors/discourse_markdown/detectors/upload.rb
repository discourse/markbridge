# frozen_string_literal: true

module Markbridge
  module Processors
    module DiscourseMarkdown
      module Detectors
        # Detects Discourse upload references using upload:// URLs.
        #
        # Supports two formats:
        # - Images: ![alt|dimensions](upload://sha1.ext)
        # - Attachments: [filename|attachment](upload://sha1.ext) (size)
        #
        # @example Image
        #   detector = Upload.new
        #   input = "![logo|64x64](upload://abc123.png)"
        #   match = detector.detect(input, 0)
        #   match.node.type # => :image
        #
        # @example Attachment
        #   detector = Upload.new
        #   input = "[doc.pdf|attachment](upload://xyz789.pdf) (1.2 MB)"
        #   match = detector.detect(input, 0)
        #   match.node.type # => :attachment
        class Upload < Base
          # Pattern for image: ![alt|dimensions](upload://sha1.ext)
          IMAGE_PATTERN = %r{!\[([^\]]*)\]\(upload://([^)]+)\)}

          # Pattern for attachment: [filename|attachment](upload://sha1.ext) followed by optional (size)
          ATTACHMENT_PATTERN = %r{\[([^\]]*\|attachment)\]\(upload://([^)]+)\)(\s*\([^)]+\))?}

          # Attempt to detect an upload at the given position.
          #
          # @param input [String] the full input string
          # @param pos [Integer] current position to check
          # @return [Match, nil] match result or nil if no match
          def detect(input, pos)
            char = input[pos]
            return nil unless char == "!" || char == "["

            remaining = input[pos..]

            if char == "!"
              detect_image(remaining, pos)
            else
              detect_attachment(remaining, pos)
            end
          end

          private

          def detect_image(remaining, pos)
            match = IMAGE_PATTERN.match(remaining)
            return nil unless match&.begin(0)&.zero?

            raw = match[0]
            alt_part = match[1]
            url_part = match[2]

            # Parse alt and dimensions from "alt|dimensions" format
            alt, dimensions = parse_alt_dimensions(alt_part)

            # Extract SHA1 and filename from URL
            sha1, filename = parse_upload_url(url_part)

            node = AST::Upload.new(sha1:, filename:, type: :image, alt:, dimensions:, raw:)

            Match.new(start_pos: pos, end_pos: pos + raw.length, node:)
          end

          def detect_attachment(remaining, pos)
            match = ATTACHMENT_PATTERN.match(remaining)
            return nil unless match&.begin(0)&.zero?

            raw = match[0]
            name_part = match[1]
            url_part = match[2]
            size_part = match[3]

            # Parse filename from "filename|attachment" format
            filename = name_part.sub(/\|attachment$/i, "")

            # Extract SHA1 from URL
            sha1, _url_filename = parse_upload_url(url_part)

            # Parse size if present
            size = size_part&.strip&.delete_prefix("(")&.delete_suffix(")")

            node = AST::Upload.new(sha1:, filename:, type: :attachment, size:, raw:)

            Match.new(start_pos: pos, end_pos: pos + raw.length, node:)
          end

          def parse_alt_dimensions(alt_part)
            return nil, nil if alt_part.nil? || alt_part.empty?

            if alt_part.include?("|")
              parts = alt_part.split("|", 2)
              alt = parts[0].empty? ? nil : parts[0]
              dimensions = parts[1]
              [alt, dimensions]
            else
              [alt_part, nil]
            end
          end

          def parse_upload_url(url_part)
            # URL format: sha1.ext or just sha1
            if url_part.include?(".")
              parts = url_part.split(".", 2)
              sha1 = parts[0]
              filename = url_part
            else
              sha1 = url_part
              filename = nil
            end

            [sha1, filename]
          end
        end
      end
    end
  end
end
