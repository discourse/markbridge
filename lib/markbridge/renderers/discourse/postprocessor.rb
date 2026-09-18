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

        # The start of a fence line: optional indentation and list markers
        # (a fence inside a list item is indented, and one that starts an
        # item follows the marker on the same line) and a run of at least
        # three backticks or tildes. Used with +match?+ on the whole text
        # as a quick test for "no fence anywhere", so the common case
        # skips the line loop.
        FENCE_RUN = /^[ \t]*(?:(?:[-+*]|\d+[.)])[ \t]+)*(`{3,}|~{3,})/
        private_constant :FENCE_RUN

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

        # Text without any fence run takes the plain path; the line loop
        # gives the same result for it, only slower.
        def clean_document(text)
          text.match?(FENCE_RUN) ? clean_around_fences(text) : clean(text)
        end

        def clean(text)
          text = text.gsub(TRAILING_INVISIBLE_RE, "") if @strip_trailing_invisibles
          text.gsub(/\n{3,}/, "\n\n") # Max 2 consecutive newlines
            .gsub(/^[ \t]+$/, "") # Remove whitespace-only lines
        end

        # Cleans the text between fenced code blocks and copies the blocks
        # as they are. A run of newlines in front of a fence is part of the
        # text before it and is collapsed there.
        def clean_around_fences(text)
          result = +""
          prose = +""
          fence = nil

          text.each_line do |line|
            if fence
              if closes_fence?(line, fence)
                # The newline that ends the closing fence belongs to the
                # text after the block, so a run of blank lines there is
                # collapsed as a whole.
                result << line.chomp
                prose << line[line.chomp.length..]
                fence = nil
              else
                result << line
              end
            elsif (fence = opening_fence(line))
              result << clean(prose) << line
              prose = +""
            else
              prose << line
            end
          end

          result << clean(prose)
        end

        # The fence run when +line+ opens a fenced code block, else nil. A
        # backtick fence cannot have a backtick after its run (CommonMark
        # 4.5), which keeps an inline code span from opening a fence.
        # @param line [String]
        # @return [String, nil]
        def opening_fence(line)
          match = FENCE_RUN.match(line)
          return nil unless match

          run = match[1]
          return nil if run.include?("`") && match.post_match.include?("`")

          run
        end

        # A closing fence is a run of the same character, at least as long
        # as the opening run, with nothing but whitespace around it.
        # @param line [String]
        # @param run [String] the opening run
        # @return [Boolean]
        def closes_fence?(line, run)
          candidate = line.strip
          candidate.length >= run.length && candidate.squeeze == run.squeeze
        end

        DEFAULT = new
      end
    end
  end
end
