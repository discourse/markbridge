# frozen_string_literal: true

module Markbridge
  # Loop-progress guard for parser/scanner dispatch loops.
  #
  # Every iteration of a dispatch loop must advance the cursor or exit
  # the loop. Mixing in ProgressGuard and calling `progressed!(pos)` at
  # the top of the loop body ensures a stalled iteration raises
  # `ParserStuckError` instead of hanging.
  #
  # The guard persists state in `@last_progress_pos` on the including
  # instance. Callers whose `parse`/`scan` entry may be invoked more
  # than once on the same instance should call `reset_progress_guard`
  # at entry to avoid stale state leaking between invocations.
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
      if @last_progress_pos && pos <= @last_progress_pos
        raise ParserStuckError.new(parser: self.class, pos:)
      end

      @last_progress_pos = pos
    end

    def reset_progress_guard
      @last_progress_pos = nil
    end
  end
end
