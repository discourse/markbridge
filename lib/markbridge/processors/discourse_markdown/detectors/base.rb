# frozen_string_literal: true

module Markbridge
  module Processors
    module DiscourseMarkdown
      module Detectors
        # Result of a successful detection
        # @attr_reader start_pos [Integer] start position in input
        # @attr_reader end_pos [Integer] end position in input (exclusive)
        # @attr_reader node [AST::Node] the AST node representing the detected construct
        Match = Data.define(:start_pos, :end_pos, :node)

        # Base class for construct detectors.
        # Subclasses implement detection logic for specific constructs
        # (mentions, polls, events, uploads).
        #
        # @abstract Subclass and implement {#detect}
        class Base
          # Attempt to detect a construct at the given position.
          #
          # @param input [String] the full input string
          # @param pos [Integer] current position to check
          # @return [Match, nil] match result or nil if no match
          def detect(input, pos)
            raise NotImplementedError, "#{self.class} must implement #detect"
          end

          private

          # Helper to check if position is at a word boundary (for mentions, etc.)
          # @param input [String] the input string
          # @param pos [Integer] position to check
          # @return [Boolean] true if at word boundary
          def word_boundary?(input, pos)
            return true if pos == 0

            prev_char = input[pos - 1]
            !prev_char.match?(/\w/)
          end

          # Helper to extract a word starting at position
          # @param input [String] the input string
          # @param pos [Integer] starting position
          # @return [String] the word (may be empty)
          def extract_word(input, pos)
            word = +""
            while pos < input.length && input[pos].match?(/[\w\-]/)
              word << input[pos]
              pos += 1
            end
            word
          end
        end
      end
    end
  end
end
