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
          TAG_PATTERN = %r{\A\[poll(?<attrs>[^\]]*)\](?<content>.*?)\[/poll\]}im

          # Attempt to detect a poll at the given position.
          #
          # @param input [String] the full input string
          # @param pos [Integer] current position to check
          # @return [Match, nil] match result or nil if no match
          def detect(input, pos)
            match = TAG_PATTERN.match(input[pos..])
            return nil unless match

            attrs = parse_attributes(match[:attrs])
            node =
              AST::Poll.new(
                name: attrs["name"] || "poll",
                type: attrs["type"],
                results: attrs["results"],
                public: attrs["public"] == "true",
                chart_type: attrs["charttype"],
                options: extract_options(match[:content]),
                raw: match[0],
              )

            Match.new(start_pos: pos, end_pos: pos + match.end(0), node:)
          end

          private

          OPTION_PATTERN = /\A\s*(?:\*\s|-\s|\d+\.\s+)(?<value>.+?)\s*\z/

          def extract_options(content)
            content.each_line.filter_map { |line| OPTION_PATTERN.match(line)&.[](:value) }
          end
        end
      end
    end
  end
end
