# frozen_string_literal: true

module Markbridge
  module Processors
    module DiscourseMarkdown
      module Detectors
        # Detects Discourse poll blocks [poll]...[/poll].
        #
        # @example
        #   detector = Poll.new
        #   input = "[poll type=\"regular\"]\n* A\n* B\n[/poll]"
        #   match = detector.detect(input, 0)
        #   match.node.type # => "regular"
        class Poll < Base
          OPEN_TAG_PATTERN = /\[poll([^\]]*)\]/i
          CLOSE_TAG_PATTERN = %r{\[/poll\]}i

          # Attempt to detect a poll at the given position.
          #
          # @param input [String] the full input string
          # @param pos [Integer] current position to check
          # @return [Match, nil] match result or nil if no match
          def detect(input, pos)
            return nil unless input[pos] == "["

            # Check for opening tag
            remaining = input[pos..]
            open_match = OPEN_TAG_PATTERN.match(remaining)
            return nil unless open_match&.begin(0)&.zero?

            # Find closing tag
            close_match = CLOSE_TAG_PATTERN.match(remaining, open_match.end(0))
            return nil unless close_match

            # Extract raw content
            end_pos = pos + close_match.end(0)
            raw = input[pos...end_pos]

            # Parse attributes from opening tag
            attrs = parse_attributes(open_match[1])

            # Extract options from content between tags
            content = remaining[open_match.end(0)...close_match.begin(0)]
            options = extract_options(content)

            node =
              AST::Poll.new(
                name: attrs["name"] || "poll",
                type: attrs["type"],
                results: attrs["results"],
                public: attrs["public"] == "true",
                chart_type: attrs["charttype"] || attrs["chartType"],
                options:,
                raw:,
              )

            Match.new(start_pos: pos, end_pos:, node:)
          end

          private

          def parse_attributes(attr_string)
            attrs = {}
            return attrs if attr_string.nil? || attr_string.empty?

            # Match key="value" or key='value' patterns
            attr_string.scan(/(\w+)=["']([^"']*)["']/) { |key, value| attrs[key.downcase] = value }

            attrs
          end

          def extract_options(content)
            options = []
            content.each_line do |line|
              line = line.strip
              if line.start_with?("* ")
                options << line[2..].strip
              elsif line.start_with?("- ")
                options << line[2..].strip
              elsif line.match?(/^\d+\.\s/)
                options << line.sub(/^\d+\.\s*/, "").strip
              end
            end
            options
          end
        end
      end
    end
  end
end
