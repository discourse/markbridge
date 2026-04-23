# frozen_string_literal: true

module Markbridge
  # Raised when a parser/scanner main loop fails to advance its cursor.
  # Every iteration of a dispatch loop must either advance the position
  # or exit the loop; failing that indicates a bug in the dispatch code.
  class ParserStuckError < StandardError
    def initialize(parser:, pos:)
      super("#{parser} stuck at position #{pos} — dispatch did not advance the cursor")
    end
  end
end
