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
          # Image: ![alt|dimensions](upload://sha1.ext)
          IMAGE_PATTERN =
            %r{\A!\[(?<alt>[^|\]]*)(?:\|(?<dimensions>[^\]]*))?\]\(upload://(?<url>[^)]+)\)}

          # Attachment: [filename|attachment](upload://sha1.ext) (size)
          ATTACHMENT_PATTERN =
            %r{
            \A
            \[(?<filename>[^|\]]*)\|attachment\]
            \(upload://(?<url>[^)]+)\)
            (?:\s*\((?<size>[^)]+)\))?
          }xi

          # Attempt to detect an upload at the given position.
          #
          # @param input [String] the full input string
          # @param pos [Integer] current position to check
          # @return [Match, nil] match result or nil if no match
          def detect(input, pos)
            remaining = input[pos..]
            case input[pos]
            when "!"
              detect_image(remaining, pos)
            when "["
              detect_attachment(remaining, pos)
            end
          end

          private

          def detect_image(remaining, pos)
            match = IMAGE_PATTERN.match(remaining)
            return nil unless match

            sha1, filename = parse_upload_url(match[:url])
            alt = match[:alt]
            alt = nil if alt.empty?

            # `type: :image` is omitted because it is AST::Upload's default -
            # passing it explicitly was an equivalent-mutation surface.
            node =
              AST::Upload.new(sha1:, filename:, alt:, dimensions: match[:dimensions], raw: match[0])

            Match.new(start_pos: pos, end_pos: pos + match[0].length, node:)
          end

          def detect_attachment(remaining, pos)
            match = ATTACHMENT_PATTERN.match(remaining)
            return nil unless match

            sha1, = parse_upload_url(match[:url])

            node =
              AST::Upload.new(
                sha1:,
                filename: match[:filename],
                type: :attachment,
                size: match[:size],
                raw: match[0],
              )

            Match.new(start_pos: pos, end_pos: pos + match[0].length, node:)
          end

          # URL format: sha1.ext or just sha1. Returns [sha1, filename-or-nil].
          def parse_upload_url(url_part)
            sha1, _, ext = url_part.partition(".")
            [sha1, ext.empty? ? nil : url_part]
          end
        end
      end
    end
  end
end
