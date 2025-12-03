# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # Strategy for collecting raw unparsed content between BBCode tags
      class RawContentCollector
        # Collect raw unparsed content between BBCode tags
        # @param tag_name [String] the tag to match
        # @param scanner [Scanner] the token source
        # @return [RawContentResult] result with content and closed status
        def collect(tag_name, scanner)
          depth = 1
          content = +""
          closed = false

          while (token = scanner.next_token)
            if token.is_a?(TagStartToken) && token.tag == tag_name
              depth += 1
            elsif token.is_a?(TagEndToken) && token.tag == tag_name
              if (depth -= 1) == 0
                closed = true
                break
              end
            end

            content << token.source
          end

          RawContentResult.new(content:, closed:)
        end
      end
    end
  end
end
