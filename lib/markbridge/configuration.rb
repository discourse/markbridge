# frozen_string_literal: true

module Markbridge
  class Configuration
    attr_accessor :escape_hard_line_breaks, :strip_trailing_invisibles

    def initialize
      @escape_hard_line_breaks = false
      # When true, `cleanup_markdown` rstrips a small set of invisible
      # characters (NBSP, ZWSP, ZWNJ, ZWJ, WJ, ZWNBSP/BOM) at each line
      # end. Useful for cleaning Outlook/Word HTML exports where these
      # show up as soft-break hints and spacer-paragraph fillers. Adds
      # one regex pass over the rendered output (~4-5% slowdown on a
      # mixed-content benchmark), so default off; opt in if the polish
      # matters more than throughput.
      @strip_trailing_invisibles = false
    end
  end
end
