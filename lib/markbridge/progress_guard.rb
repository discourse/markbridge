# frozen_string_literal: true

module Markbridge
  # Loop-progress guard for parser/scanner dispatch loops.
  #
  # Every iteration of a dispatch loop must advance the cursor or exit
  # the loop. Mixing in ProgressGuard and calling `progressed!(pos)` at
  # the top of the loop body ensures a stalled iteration raises
  # `ParserStuckError` instead of hanging.
  #
  # State is persisted in `@last_progress_pos` on the including
  # instance. Every entry point that uses `progressed!` must call
  # `reset_progress_guard` first — the check compares against an
  # Integer sentinel (-1 after reset), so leaving the ivar unset or
  # at nil raises `ArgumentError` on the first call. A -1 sentinel
  # avoids a per-iteration `nil` short-circuit and is measurably
  # friendlier to YJIT on hot inline loops.
  #
  # @example
  #   class MyParser
  #     include Markbridge::ProgressGuard
  #
  #     def parse(input)
  #       reset_progress_guard
  #       while @pos < input.length
  #         progressed!(@pos)
  #         # ... body that must advance @pos ...
  #       end
  #     end
  #   end
  module ProgressGuard
    private

    def progressed!(pos)
      raise ParserStuckError.new(parser: self.class, pos:) if pos <= @last_progress_pos

      @last_progress_pos = pos
    end

    def reset_progress_guard
      @last_progress_pos = -1
    end
  end
end
