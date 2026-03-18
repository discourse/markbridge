# frozen_string_literal: true

module Markbridge
  module Processors
    module DiscourseMarkdown
      module Detectors
        # Detects Discourse event blocks [event]...[/event].
        #
        # @example
        #   detector = Event.new
        #   input = '[event name="Meeting" start="2025-12-15 14:00"][/event]'
        #   match = detector.detect(input, 0)
        #   match.node.name # => "Meeting"
        class Event < Base
          OPEN_TAG_PATTERN = /\[event([^\]]*)\]/i
          CLOSE_TAG_PATTERN = %r{\[/event\]}i

          # Attempt to detect an event at the given position.
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

            # Validate required attributes
            return nil unless attrs["name"] && attrs["start"]

            node =
              AST::Event.new(
                name: attrs["name"],
                starts_at: attrs["start"],
                ends_at: attrs["end"],
                status: attrs["status"],
                timezone: attrs["timezone"],
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
        end
      end
    end
  end
end
