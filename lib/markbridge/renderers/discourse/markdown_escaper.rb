# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Escapes text to prevent interpretation as Markdown formatting.
      #
      # Design principles:
      # - No false negatives: all potentially special sequences MUST be escaped
      # - False positives OK: over-escaping is acceptable for safety
      # - Autolinks preserved: <https://...>, <mailto:...>, and <email@domain> remain functional
      # - HTML escaped: tags, processing instructions, and SGML declarations are neutralized
      # - Performance: minimal allocations, byte-level processing, early returns
      # - Discourse-compatible: handles ndash conversion, unlimited ordered list numbers
      #
      # Optimized for Ruby 3.3+ with YJIT. Key optimizations:
      # - Fast path returns original string for plain text (no allocations)
      # - Pre-allocated result buffers with estimated capacity
      # - Byte-level processing for inline escaping (YJIT-friendly tight loops)
      # - Simplified escaping rules: [ breaks links, so ] doesn't need escaping
      #
      # @example Basic escaping
      #   escaper = Markbridge::Renderers::Discourse::MarkdownEscaper.new
      #   escaper.escape("# Heading")      # => "\\# Heading"
      #   escaper.escape("*emphasis*")     # => "\\*emphasis\\*"
      #   escaper.escape("foo -- bar")     # => "foo \\-\\- bar"
      #
      # @example HTML is escaped
      #   escaper.escape("<div>content</div>")  # => "\\<div>content\\</div>"
      #   escaper.escape("<?php echo 1; ?>")    # => "\\<?php echo 1; ?>"
      #
      class MarkdownEscaper
        # @param escape_hard_line_breaks [Boolean] when true, strip trailing spaces
        #   before newlines to prevent CommonMark hard line breaks (<br/>).
        #   Defaults to false because Discourse has trailing-space hard line
        #   breaks disabled by default.
        def initialize(escape_hard_line_breaks: false)
          @escape_hard_line_breaks = escape_hard_line_breaks
          @inline_content = nil
          @inline_result = nil
          @inline_len = 0
        end

        # Fast-path check: any character that might need escaping
        # Only includes characters we actually escape (removed ], {, }, ^)
        # > is needed for blockquote detection at line start
        MAYBE_SPECIAL = /[\\`*_\[#+\-.!<>&|~=>)]/

        # Check for indented code on any line
        # Matches: 4+ spaces, tab, or space+tab combinations that reach column 4+
        MAYBE_INDENTED_CODE = /(?:^|\n)(?: {4}|\t| {1,3}\t)/

        # Block-level patterns
        ATX_HEADING = /\A\#{1,6}(?=[ \t]|$)/
        BLOCK_QUOTE = /\A>/
        # List markers followed by space, tab, or end of line
        BULLET_LIST = /\A[-+*](?=[ \t]|$)/
        ORDERED_LIST = /\A(\d+)([.)])(?=[ \t])/
        THEMATIC_BREAK_DASH = /\A(?:-[ \t]*){3,}$/
        THEMATIC_BREAK_STAR = /\A(?:\*[ \t]*){3,}$/
        THEMATIC_BREAK_UNDERSCORE = /\A(?:_[ \t]*){3,}$/
        FENCED_CODE_BACKTICK = /\A`{3,}[^`]*$/
        FENCED_CODE_TILDE = /\A~{3,}/
        SETEXT_UNDERLINE_EQUALS = /\A=+[ \t]*$/
        SETEXT_UNDERLINE_DASH = /\A-+[ \t]*$/
        # Indented code: 4+ spaces, tab at start, or space+tab reaching column 4+
        INDENTED_CODE = /\A(?: {4}|\t| {1,3}\t)/

        # Inline quick-check pattern (includes < for HTML tag escaping)
        INLINE_SPECIAL = /[\\*_`\[!|<&~-]/

        # Entity reference pattern (we escape these to prevent conversion)
        ENTITY_REF = /\A&(?:\#[xX][0-9a-fA-F]{1,6}|\#[0-9]{1,7}|[a-zA-Z][a-zA-Z0-9]{0,31});/

        # HTML tag pattern (we escape these, but NOT autolinks)
        # Handles quoted attributes which can contain > characters
        # Attribute patterns: name="value" | name='value' | name=value | name
        HTML_ATTR = /(?:\s+[a-zA-Z_:][a-zA-Z0-9_.:-]*(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s"'=<>`]+))?)/
        HTML_TAG = %r{\A</?[a-zA-Z][a-zA-Z0-9-]*#{HTML_ATTR}*\s*/?>}

        # Autolink pattern - we pass these through entirely unchanged
        # Matches <http://...>, <https://...>, <mailto:...>, and email addresses
        AUTOLINK =
          %r{\A<(?:https?://|mailto:)[^>\s]*>|\A<[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*>}i

        # Match HTML-like constructs that need escaping:
        # - Processing instructions: <?php, <?xml, etc.
        # - SGML declarations: <!DOCTYPE, <!ELEMENT, <![CDATA[, <!--, etc.
        # - Incomplete/multi-line HTML tags: <div followed by attributes on next line
        # - Custom elements: <my-component>, <responsive-image>
        # The (?:[\s/]|$) ensures we don't match comparisons like "a < b"
        HTML_TAG_START = %r{\A<(?:[?!]|/?\s*[a-zA-Z][a-zA-Z0-9-]*(?:[\s/]|$))}

        # Byte constants for inline processing
        BACKSLASH = 92 # \
        BANG = 33 # !
        HASH = 35 # #
        AMP = 38 # &
        STAR = 42 # *
        PLUS = 43 # +
        DASH = 45 # -
        LT = 60 # <
        EQUALS = 61 # =
        GT = 62 # >
        BRACKET_OPEN = 91 # [
        UNDERSCORE = 95 # _
        BACKTICK = 96 # `
        PIPE = 124 # |
        TILDE = 126 # ~
        SPACE = 32
        TAB = 9
        DIGIT_0 = 48
        DIGIT_9 = 57

        # Escapes markdown special characters in the given text.
        #
        # Handles both block-level constructs (headings, lists, code blocks, HTML blocks)
        # and inline formatting (emphasis, code spans, links, inline HTML).
        # Autolinks (<https://...>, <email@domain>) are intentionally preserved.
        #
        # @param text [String, nil] the text to escape
        # @return [String] the escaped text, or empty string if input is nil
        # @note Multi-line HTML tags and blocks are handled by escaping the opening <
        def escape(text)
          return "" if text.nil?

          # Neutralize hard line breaks (trailing 2+ spaces before newline)
          text = text.gsub(/  +\n/, "\n") if @escape_hard_line_breaks && text.include?("  \n")

          return text unless MAYBE_SPECIAL.match?(text) || MAYBE_INDENTED_CODE.match?(text)

          escape_text(text)
        end

        private

        def escape_text(text)
          lines = text.split("\n", -1)
          return escape_line(lines[0], false) if lines.size == 1

          # Pre-allocate result buffer
          bytesize = text.bytesize
          result = String.new(capacity: bytesize + bytesize / 3, encoding: text.encoding)
          prev_was_paragraph = false
          first = true

          lines.each do |line|
            result << "\n" unless first
            first = false

            escaped = escape_line(line, prev_was_paragraph)
            result << escaped
            prev_was_paragraph = paragraph_line?(line)
          end

          result
        end

        def escape_line(line, prev_was_paragraph)
          return line if line.empty?
          return escape_indented_code(line) if INDENTED_CODE.match?(line)

          # After INDENTED_CODE, line has at most 3 leading spaces, so the
          # `< 3` bound keeps this a tight YJIT-friendly hot loop.
          #
          # Split into `while <bound>` + `break if` rather than the natural
          # `while <bound> && <byte-check>` to avoid a Ruby 3.4.8 PRISM VM
          # bug: mutant generates `while nil && <expr>` mutations which
          # segfault (https://bugs.ruby-lang.org/issues/22002, fixed in
          # 3.4.10). Revisit once 3.4.10 is our minimum.
          indent_len = 0
          while indent_len < 3
            break if line.getbyte(indent_len) != SPACE
            indent_len += 1
          end

          # Whitespace-only line (1-3 spaces) — getbyte past end is nil.
          return line if line.getbyte(indent_len).nil?

          has_indent = indent_len > 0
          content = has_indent ? line[indent_len..] : line

          escaped, skip_inline = escape_block_level(content, prev_was_paragraph)
          escaped = escape_inline(escaped) unless skip_inline

          if has_indent
            result = String.new(encoding: line.encoding)
            result << line[0, indent_len] << escaped
            result
          else
            escaped.force_encoding(line.encoding)
          end
        end

        # Non-breaking space - used to preserve visual indentation without
        # triggering code blocks or block-level markdown
        NBSP = "\u00A0"

        def escape_indented_code(line)
          # Replace leading whitespace with NBSP to prevent code block interpretation.
          # NBSP is not whitespace to CommonMark, so:
          # - Line doesn't start with 4+ spaces (no code block)
          # - Content doesn't start at valid block position (no lists, headings, etc.)
          # - Visual indentation is preserved (NBSP renders as space)
          # We still escape inline content since it's no longer protected.
          line_length = line.length
          ws_end = 0
          while ws_end < line_length
            byte = line.getbyte(ws_end)
            break if byte != SPACE && byte != TAB
            ws_end += 1
          end

          return line if ws_end == 0 # No leading whitespace (shouldn't happen, but safe)
          return line if ws_end >= line_length # Whitespace-only line

          # Convert leading whitespace to NBSP (tab = 4 NBSP for visual consistency)
          nbsp_indent = String.new(encoding: line.encoding)
          line[0, ws_end].each_char { |char| nbsp_indent << (char == "\t" ? (NBSP * 4) : NBSP) }

          content = line[ws_end..]
          "#{nbsp_indent}#{escape_inline(content)}"
        end

        def escape_block_level(content, prev_was_paragraph)
          first_byte = content.getbyte(0)

          case first_byte
          when HASH
            return escape_first_char_inline(content, "\\#") if ATX_HEADING.match?(content)
          when GT
            return escape_first_char_inline(content, "\\>")
          when DASH
            return escape_block_dash(content, prev_was_paragraph)
          when PLUS
            return escape_first_char_inline(content, "\\+") if BULLET_LIST.match?(content)
          when STAR
            return escape_block_star(content)
          when UNDERSCORE
            if THEMATIC_BREAK_UNDERSCORE.match?(content)
              return escape_all_chars(content, UNDERSCORE, "\\_"), true
            end
          when EQUALS
            if prev_was_paragraph && SETEXT_UNDERLINE_EQUALS.match?(content)
              return escape_all_chars(content, EQUALS, "\\="), true
            end
          when BACKTICK
            if FENCED_CODE_BACKTICK.match?(content)
              return escape_all_chars(content, BACKTICK, "\\`"), true
            end
          when TILDE
            return "\\#{content}", true if FENCED_CODE_TILDE.match?(content)
          when BRACKET_OPEN
            return escape_first_char_inline(content, "\\[")
          when PIPE
            return escape_first_char_inline(content, "\\|")
          when DIGIT_0..DIGIT_9
            return escape_block_ordered_list(content)
          end

          [content, false]
        end

        # Escape the first character and inline-escape the rest.
        def escape_first_char_inline(content, escaped_char)
          ["#{escaped_char}#{escape_inline(content[1..])}", true]
        end

        def escape_block_dash(content, prev_was_paragraph)
          if THEMATIC_BREAK_DASH.match?(content) ||
               (prev_was_paragraph && SETEXT_UNDERLINE_DASH.match?(content))
            return escape_all_chars(content, DASH, "\\-"), true
          end
          return escape_first_char_inline(content, "\\-") if BULLET_LIST.match?(content)
          [content, false]
        end

        def escape_block_star(content)
          return escape_all_chars(content, STAR, "\\*"), true if THEMATIC_BREAK_STAR.match?(content)
          return escape_first_char_inline(content, "\\*") if BULLET_LIST.match?(content)
          [content, false]
        end

        def escape_block_ordered_list(content)
          if (match = ORDERED_LIST.match(content))
            rest = content[match[0].length..]
            return "#{match[1]}\\#{match[2]}#{escape_inline(rest)}", true
          end
          [content, false]
        end

        def escape_all_chars(str, byte_val, escaped)
          result = String.new(capacity: str.bytesize * 2, encoding: str.encoding)
          str.each_byte do |byte|
            if byte == byte_val
              result << escaped
            else
              result << byte
            end
          end
          result
        end

        def escape_inline(content)
          return content unless INLINE_SPECIAL.match?(content)

          bytesize = content.bytesize
          @inline_content = content
          @inline_result = String.new(capacity: bytesize + bytesize / 4, encoding: content.encoding)
          @inline_len = bytesize
          pos = 0

          while pos < @inline_len
            byte = @inline_content.getbyte(pos)
            pos = dispatch_inline_byte(byte, pos)
          end

          @inline_result
        end

        def dispatch_inline_byte(byte, pos)
          case byte
          when BACKSLASH
            escape_backslash(pos)
          when DASH
            escape_consecutive_pair(pos, DASH, "\\-")
          when TILDE
            escape_tilde_pair(pos)
          when STAR
            escape_char_run(pos, STAR, "\\*")
          when UNDERSCORE
            escape_char_run(pos, UNDERSCORE, "\\_")
          when BACKTICK
            escape_char_run(pos, BACKTICK, "\\`")
          when BANG
            escape_image_open(pos)
          when BRACKET_OPEN
            @inline_result << "\\["
            pos + 1
          when PIPE
            @inline_result << "\\|"
            pos + 1
          when LT
            escape_lt(pos)
          when AMP
            escape_amp(pos)
          else
            escape_regular_char(byte, pos)
          end
        end

        # Escape backslash before ASCII punctuation or at end of content.
        def escape_backslash(pos)
          next_pos = pos + 1
          if next_pos >= @inline_len || ascii_punctuation?(@inline_content.getbyte(next_pos))
            @inline_result << "\\\\"
          else
            @inline_result << BACKSLASH
          end
          next_pos
        end

        # Escape consecutive pairs (e.g., -- for ndash prevention) or pass single through.
        def escape_consecutive_pair(pos, byte_val, escaped)
          next_pos = pos + 1
          if next_pos < @inline_len && @inline_content.getbyte(next_pos) == byte_val
            escape_char_run(pos, byte_val, escaped)
          else
            @inline_result << byte_val
            next_pos
          end
        end

        # Escape ~~ pairs, pass single ~ through.
        def escape_tilde_pair(pos)
          next_pos = pos + 1
          if next_pos < @inline_len && @inline_content.getbyte(next_pos) == TILDE
            @inline_result << "\\~\\~"
            pos + 2
          else
            @inline_result << TILDE
            next_pos
          end
        end

        # Escape all consecutive occurrences of a repeatable character (*, _, `).
        #
        # Split into `while <bound>` + `break if` rather than the natural
        # `while <bound> && <byte-check>` to avoid a Ruby 3.4.8 PRISM VM bug
        # (https://bugs.ruby-lang.org/issues/22002, fixed in 3.4.10).
        def escape_char_run(pos, byte_val, escaped)
          while pos < @inline_len
            break if @inline_content.getbyte(pos) != byte_val
            @inline_result << escaped
            pos += 1
          end
          pos
        end

        # Escape ![ image syntax, pass standalone ! through.
        def escape_image_open(pos)
          next_pos = pos + 1
          if next_pos < @inline_len && @inline_content.getbyte(next_pos) == BRACKET_OPEN
            @inline_result << "\\!\\["
            pos + 2
          else
            @inline_result << BANG
            next_pos
          end
        end

        # Handle < for autolinks (preserved), HTML tags (escaped), and other constructs.
        def escape_lt(pos)
          remaining = remaining_content(pos)

          if (match = AUTOLINK.match(remaining))
            matched = match[0]
            @inline_result << matched
            pos + matched.bytesize
          elsif (match = HTML_TAG.match(remaining))
            matched = match[0]
            @inline_result << "\\" << matched.gsub("`") { "\\`" }
            pos + matched.bytesize
          elsif HTML_TAG_START.match?(remaining)
            @inline_result << "\\<"
            pos + 1
          else
            @inline_result << LT
            pos + 1
          end
        end

        # Handle & for entity references.
        def escape_amp(pos)
          remaining = remaining_content(pos)

          if (match = ENTITY_REF.match(remaining))
            matched = match[0]
            @inline_result << "\\" << matched
            pos + matched.bytesize
          else
            @inline_result << AMP
            pos + 1
          end
        end

        def remaining_content(pos)
          @inline_content.byteslice(pos, @inline_len - pos)
        end

        # Handle regular characters including multi-byte UTF-8.
        def escape_regular_char(byte, pos)
          if byte < 128
            @inline_result << byte
            pos + 1
          else
            char_len = utf8_char_length(byte)
            end_pos = [pos + char_len, @inline_len].min
            @inline_result << @inline_content.byteslice(pos, end_pos - pos)
            end_pos
          end
        end

        def ascii_punctuation?(byte)
          (byte >= 33 && byte <= 47) || (byte >= 58 && byte <= 64) || (byte >= 91 && byte <= 96) || # !"#$%&'()*+,-./ # :;<=>?@ # [\]^_`
            (byte >= 123 && byte <= 126) # {|}~
        end

        def utf8_char_length(first_byte)
          if first_byte >= 240
            4
          elsif first_byte >= 224
            3
          elsif first_byte >= 192
            2
          else
            1
          end
        end

        def paragraph_line?(line)
          first_non_space = 0
          first_non_space += 1 while line.getbyte(first_non_space) == SPACE

          # Empty or whitespace-only lines: getbyte past the end returns nil.
          return false if line.getbyte(first_non_space).nil?

          # Indented code (4+ spaces or any leading \t) is not a paragraph.
          # INDENTED_CODE also catches lines where first_non_space > 3, so no
          # separate numeric boundary check is needed.
          return false if INDENTED_CODE.match?(line)

          content = first_non_space == 0 ? line : line[first_non_space..]

          # Lines starting with [ are paragraph content (the escaper rewrites [
          # to \[). block_construct? has no BRACKET_OPEN case arm, so such
          # lines naturally fall through and !block_construct?(content) == true.
          !block_construct?(content)
        end

        # Checks whether content starts with a block-level markdown construct.
        # Used by both escape_block_level (to decide what to escape) and
        # paragraph_line? (to decide if setext underlines can follow).
        def block_construct?(content)
          case content.getbyte(0)
          when HASH
            ATX_HEADING.match?(content)
          when GT
            true
          when DASH
            BULLET_LIST.match?(content) || THEMATIC_BREAK_DASH.match?(content)
          when STAR
            BULLET_LIST.match?(content) || THEMATIC_BREAK_STAR.match?(content)
          when PLUS
            BULLET_LIST.match?(content)
          when UNDERSCORE
            THEMATIC_BREAK_UNDERSCORE.match?(content)
          when BACKTICK
            FENCED_CODE_BACKTICK.match?(content)
          when TILDE
            FENCED_CODE_TILDE.match?(content)
          when DIGIT_0..DIGIT_9
            ORDERED_LIST.match?(content)
          else
            false
          end
        end
      end
    end
  end
end
