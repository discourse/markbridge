# frozen_string_literal: true

module Markbridge
  module AST
    # Represents a Discourse poll.
    #
    # @example Basic poll
    #   poll = AST::Poll.new(
    #     name: "poll",
    #     type: "regular",
    #     options: ["A", "B", "C"]
    #   )
    #
    # @example Poll with all attributes
    #   poll = AST::Poll.new(
    #     name: "favorite-color",
    #     type: "multiple",
    #     results: "on_vote",
    #     public: true,
    #     chart_type: "pie",
    #     options: ["Red", "Blue", "Green"],
    #     raw: "[poll name=\"favorite-color\"]..."
    #   )
    class Poll < Node
      # @return [String] the poll name/identifier
      attr_reader :name

      # @return [String, nil] poll type (regular, multiple, number)
      attr_reader :type

      # @return [String, nil] when to show results (always, on_vote, on_close, staff_only)
      attr_reader :results

      # @return [Boolean] whether votes are public
      attr_reader :public

      # @return [String, nil] chart type (bar, pie)
      attr_reader :chart_type

      # @return [Array<String>] poll options
      attr_reader :options

      # @return [String, nil] the original raw BBCode
      attr_reader :raw

      # Create a new Poll node.
      #
      # @param name [String] the poll name/identifier
      # @param type [String, nil] poll type
      # @param results [String, nil] when to show results
      # @param public [Boolean] whether votes are public
      # @param chart_type [String, nil] chart type
      # @param options [Array<String>] poll options
      # @param raw [String, nil] the original raw BBCode
      def initialize(
        name: "poll",
        type: nil,
        results: nil,
        public: false,
        chart_type: nil,
        options: [],
        raw: nil
      )
        @name = name
        @type = type
        @results = results
        @public = public
        @chart_type = chart_type
        @options = options
        @raw = raw
      end
    end
  end
end
