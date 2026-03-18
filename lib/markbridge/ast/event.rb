# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a Discourse event.
    #
    # @example Basic event
    #   event = AST::Event.new(
    #     name: "Team Meeting",
    #     starts_at: "2025-12-15 14:00"
    #   )
    #
    # @example Event with all attributes
    #   event = AST::Event.new(
    #     name: "Conference",
    #     starts_at: "2025-12-15 09:00",
    #     ends_at: "2025-12-15 17:00",
    #     status: "public",
    #     timezone: "Europe/Vienna",
    #     raw: "[event name=\"Conference\"]...[/event]"
    #   )
    class Event < Node
      # @return [String] the event name
      attr_reader :name

      # @return [String] start date/time
      attr_reader :starts_at

      # @return [String, nil] end date/time
      attr_reader :ends_at

      # @return [String, nil] event status (public, private, standalone)
      attr_reader :status

      # @return [String, nil] timezone
      attr_reader :timezone

      # @return [String, nil] the original raw BBCode
      attr_reader :raw

      # Create a new Event node.
      #
      # @param name [String] the event name
      # @param starts_at [String] start date/time
      # @param ends_at [String, nil] end date/time
      # @param status [String, nil] event status
      # @param timezone [String, nil] timezone
      # @param raw [String, nil] the original raw BBCode
      def initialize(name:, starts_at:, ends_at: nil, status: nil, timezone: nil, raw: nil)
        @name = name
        @starts_at = starts_at
        @ends_at = ends_at
        @status = status
        @timezone = timezone
        @raw = raw
      end
    end
  end
end
