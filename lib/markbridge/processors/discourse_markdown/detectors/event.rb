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
          OPEN_TAG_PATTERN = /\[event(?<attrs>[^\]]*)\]/i
          CLOSE_TAG_PATTERN = %r{\[/event\]}i

          # Attempt to detect an event at the given position.
          #
          # @param input [String] the full input string
          # @param pos [Integer] current position to check
          # @return [Match, nil] match result or nil if no match
          def detect(input, pos)
            remaining = input[pos..]
            open_match = OPEN_TAG_PATTERN.match(remaining)
            return nil unless open_match&.begin(0)&.zero?

            # Find closing tag. The opening tag pattern forbids `]` between
            # `[event` and its closing `]`, so `[/event]` cannot appear inside
            # the opening tag - no need to skip past it.
            close_match = CLOSE_TAG_PATTERN.match(remaining)
            return nil unless close_match

            # Extract raw content
            end_pos = pos + close_match.end(0)
            raw = input[pos...end_pos]

            # Parse attributes from opening tag
            attrs = parse_attributes(open_match[:attrs])

            # Validate required attributes
            name = attrs["name"]
            starts_at = attrs["start"]
            return nil if name.nil? || starts_at.nil?

            node =
              AST::Event.new(
                name:,
                starts_at:,
                ends_at: attrs["end"],
                status: attrs["status"],
                timezone: attrs["timezone"],
                raw:,
              )

            Match.new(start_pos: pos, end_pos:, node:)
          end

          private
        end
      end
    end
  end
end
