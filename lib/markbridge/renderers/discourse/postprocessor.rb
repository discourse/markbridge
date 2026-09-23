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
      # Steps 1 to 3 leave fenced code blocks alone: inside a fence every
      # line is code, and a blank line or a line of spaces is part of it.
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

        # A run that may open or close a fence. Found with a plain search
        # over the whole text; the line around it is then checked with the
        # anchored patterns below. An anchored pattern alone is tried at
        # every byte of the text and costs many times more.
        BACKTICK_FENCE = "```"
        TILDE_FENCE = "~~~"
        # A line that opens a fence: optional indentation and list markers
        # (a fence inside a list item is indented, and one that starts an
        # item follows the marker on the same line) and a run of at least
        # three backticks or tildes.
        OPENING_LINE = /\A[ \t]*(?:(?:[-+*]|\d+[.)])[ \t]+)*(`{3,}|~{3,})/
        # A line that closes a fence: a run of backticks or tildes alone,
        # whitespace around it allowed.
        CLOSING_LINE = /\A[ \t]*(`{3,}|~{3,})[ \t]*\z/
        private_constant :BACKTICK_FENCE, :TILDE_FENCE, :OPENING_LINE, :CLOSING_LINE

        # @param strip_trailing_invisibles [Boolean] when true, strips
        #   trailing invisible characters (NBSP and zero-width format
        #   chars) from each line before the standard cleanup pass.
        def initialize(strip_trailing_invisibles: false)
          @strip_trailing_invisibles = strip_trailing_invisibles
        end

        # @param text [String]
        # @return [String]
        def call(text)
          clean_document(text).strip # Trim leading/trailing whitespace
        end

        private

        # Text without a fence run takes the plain path; the fence scan gives
        # the same result for it, only slower. The escaper writes a backslash
        # in front of every backtick and tilde in text, so three in a row
        # only occur in a fence or in a code span with a long delimiter.
        def clean_document(text)
          if text.include?(BACKTICK_FENCE) || text.include?(TILDE_FENCE)
            clean_around_fences(text)
          else
            clean(text)
          end
        end

        # Three or more newlines in a row; the gsub brings them down to two.
        NEWLINE_RUN = /\n{3,}/
        # A line with nothing but spaces and tabs on it.
        WHITESPACE_LINE = /^[ \t]+$/
        private_constant :NEWLINE_RUN, :WHITESPACE_LINE

        # The two checks in front of the gsubs save the copy that gsub makes
        # also when nothing matches. Most text has neither three newlines
        # in a row nor a whitespace-only line.
        def clean(prose)
          prose = prose.gsub(TRAILING_INVISIBLE_RE, "") if @strip_trailing_invisibles
          prose = prose.gsub(NEWLINE_RUN, "\n\n") if prose.include?("\n\n\n")
          prose = prose.gsub(WHITESPACE_LINE, "") if prose.match?(WHITESPACE_LINE)
          prose
        end

        # Cleans the text between fenced code blocks and copies the blocks
        # as they are. Works with byte offsets and searches over the whole
        # text, so the lines inside a block cost nothing each. A run of
        # newlines in front of a fence is part of the text before it and
        # is collapsed there; the newline that ends a closing fence belongs
        # to the text after the block.
        def clean_around_fences(text)
          result = +""
          prose_start = 0
          search_from = 0

          while (candidate = fence_index(text, search_from))
            line_start = (text.byterindex("\n", candidate) || -1) + 1
            line_end = text.byteindex("\n", candidate) || text.bytesize
            run = opening_run(text.byteslice(line_start, line_end - line_start))

            # A fence starts a line, so a run elsewhere on it opens none.
            # Keep looking on the next line.
            unless run
              search_from = line_end
              next
            end

            block_end = closing_fence_end(text, line_end, run)
            result << clean(text.byteslice(prose_start, line_start - prose_start))
            result << text.byteslice(line_start, block_end - line_start)
            prose_start = search_from = block_end
          end

          result << clean(text.byteslice(prose_start, text.bytesize - prose_start))
        end

        # The offset of the next fence run of either kind at or after
        # +from+, else nil. Two string searches beat one regex with an
        # alternation: a string search runs as a byte search, the regex
        # walks the text with the engine.
        # @param text [String]
        # @param from [Integer] byte offset to start at
        # @return [Integer, nil]
        def fence_index(text, from)
          backtick = text.byteindex(BACKTICK_FENCE, from)
          tilde = text.byteindex(TILDE_FENCE, from)
          return tilde unless backtick
          return backtick unless tilde

          backtick < tilde ? backtick : tilde
        end

        # The run when +line+ opens a fenced code block, else nil. A
        # backtick fence cannot have a backtick after its run (CommonMark
        # 4.5), which keeps an inline code span from opening a fence.
        # @param line [String]
        # @return [String, nil]
        def opening_run(line)
          match = OPENING_LINE.match(line)
          return nil unless match

          run = match[1]
          run unless run.include?("`") && match.post_match.include?("`")
        end

        # The byte offset just after the closing fence of the block opened
        # by +run+, searching from +from+; the end of the text when the
        # block never closes. A closing fence is a run of the same
        # character, at least as long as the opening run, alone on its
        # line. Every such line contains +run+ itself, so a string search
        # finds the candidates and the pattern checks the whole line.
        # @param text [String]
        # @param from [Integer] byte offset to search from
        # @param run [String] the opening run
        # @return [Integer]
        def closing_fence_end(text, from, run)
          while (candidate = text.byteindex(run, from))
            # +from+ starts at the newline that ends the opening line, so
            # there is always a newline in front of a candidate.
            line_start = text.byterindex("\n", candidate) + 1
            line_end = text.byteindex("\n", candidate) || text.bytesize
            return line_end if CLOSING_LINE.match?(text.byteslice(line_start...line_end))

            from = line_end
          end

          text.bytesize
        end

        DEFAULT = new
      end
    end
  end
end
