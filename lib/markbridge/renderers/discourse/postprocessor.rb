# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Cleans up the raw Markdown produced by the Renderer:
      #
      # 1. (optional) strips trailing invisible characters per line —
      #    NBSP plus the zero-width format chars (ZWSP, ZWNJ, ZWJ, WJ,
      #    ZWNBSP/BOM). Deliberately excludes ASCII space and tab so
      #    Markdown's "two trailing spaces = hard line break" rule
      #    still works. Off by default.
      # 2. collapses runs of 3+ newlines down to two,
      # 3. clears whitespace-only lines,
      # 4. trims leading/trailing whitespace from the whole document.
      #
      # Subclass to customize. The +call+ method is the entry point.
      class Postprocessor
        # NBSP plus zero-width format chars. Spelled with explicit
        # +\u{...}+ escapes rather than the literal characters — the
        # latter are invisible in editors and easy to corrupt on
        # encoding-conversion round-trips.
        #
        #   U+00A0  NBSP        no-break space
        #   U+200B  ZWSP        zero-width space
        #   U+200C  ZWNJ        zero-width non-joiner
        #   U+200D  ZWJ         zero-width joiner
        #   U+2060  WJ          word joiner
        #   U+FEFF  ZWNBSP/BOM  zero-width no-break space / byte-order mark
        TRAILING_INVISIBLE_RE = /[\u{00A0 200B 200C 200D 2060 FEFF}]+$/

        # @param strip_trailing_invisibles [Boolean] when true, strips
        #   trailing invisible characters (NBSP and zero-width format
        #   chars) from each line before the standard cleanup pass.
        def initialize(strip_trailing_invisibles: false)
          @strip_trailing_invisibles = strip_trailing_invisibles
        end

        # @param text [String]
        # @return [String]
        def call(text)
          text = text.gsub(TRAILING_INVISIBLE_RE, "") if @strip_trailing_invisibles
          text
            .gsub(/\n{3,}/, "\n\n") # Max 2 consecutive newlines
            .gsub(/^[ \t]+$/, "") # Remove whitespace-only lines
            .strip # Trim leading/trailing whitespace
        end

        DEFAULT = new
      end
    end
  end
end
