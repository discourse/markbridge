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
          return "".freeze if text.nil?
          return text if text.empty?

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
          result = String.new(capacity: text.bytesize + text.bytesize / 3, encoding: text.encoding)
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

          # Handle indented code blocks first
          return escape_indented_code(line) if INDENTED_CODE.match?(line)

          # Extract 0-3 space indent
          indent_len = 0
          while indent_len < 3 && indent_len < line.length && line.getbyte(indent_len) == SPACE
            indent_len += 1
          end

          return line if indent_len >= line.length

          content = indent_len > 0 ? line[indent_len..] : line

          # Apply block-level escaping (which may also do inline escaping)
          escaped, skip_inline = escape_block_level(content, prev_was_paragraph)

          # Apply inline escaping if block-level didn't handle it
          escaped = escape_inline(escaped) unless skip_inline

          # Prepend indent if present, preserve encoding
          if indent_len > 0
            result = String.new(encoding: line.encoding)
            result << line[0, indent_len] << escaped
            result
          else
            # Preserve original encoding
            escaped.is_a?(String) ? escaped.force_encoding(line.encoding) : escaped
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
          i = 0
          while i < line.length
            b = line.getbyte(i)
            break if b != SPACE && b != TAB
            i += 1
          end

          return line if i == 0 # No leading whitespace (shouldn't happen, but safe)
          return line if i >= line.length # Whitespace-only line

          # Convert leading whitespace to NBSP (tab = 4 NBSP for visual consistency)
          nbsp_indent = String.new(encoding: line.encoding)
          line[0, i].each_char { |c| nbsp_indent << (c == "\t" ? (NBSP * 4) : NBSP) }

          content = line[i..]
          "#{nbsp_indent}#{escape_inline(content)}"
        end

        def escape_block_level(content, prev_was_paragraph)
          first_byte = content.getbyte(0)

          case first_byte
          when HASH
            return "\\##{escape_inline(content[1..])}", true if ATX_HEADING.match?(content)
          when GT
            return "\\>#{escape_inline(content[1..])}", true
          when DASH
            if THEMATIC_BREAK_DASH.match?(content) ||
                 (prev_was_paragraph && SETEXT_UNDERLINE_DASH.match?(content))
              return escape_all_chars(content, DASH, "\\-"), true
            end
            return "\\-#{escape_inline(content[1..])}", true if BULLET_LIST.match?(content)
          when PLUS
            return "\\+#{escape_inline(content[1..])}", true if BULLET_LIST.match?(content)
          when STAR
            if THEMATIC_BREAK_STAR.match?(content)
              return escape_all_chars(content, STAR, "\\*"), true
            end
            return "\\*#{escape_inline(content[1..])}", true if BULLET_LIST.match?(content)
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
              # Escape ALL backticks to prevent code span interpretation
              # e.g., ```` becomes \`\`\`\` not \```` (which would be \` + ```)
              return escape_all_chars(content, BACKTICK, "\\`"), true
            end
          when TILDE
            return "\\#{content}", true if FENCED_CODE_TILDE.match?(content)
          when BRACKET_OPEN
            return "\\[#{escape_inline(content[1..])}", true
          when PIPE
            return "\\|#{escape_inline(content[1..])}", true
          when DIGIT_0..DIGIT_9
            if (m = ORDERED_LIST.match(content))
              prefix = m[1]
              delim = m[2]
              rest = content[m[0].length..]
              return "#{prefix}\\#{delim}#{escape_inline(rest)}", true
            end
          end

          [content, false]
        end

        def escape_all_chars(str, byte_val, escaped)
          result = String.new(capacity: str.bytesize * 2, encoding: str.encoding)
          str.each_byte do |b|
            if b == byte_val
              result << escaped
            else
              result << b
            end
          end
          result
        end

        def escape_inline(content)
          # Quick check - if no special chars, return as-is
          return content unless INLINE_SPECIAL.match?(content)

          result =
            String.new(
              capacity: content.bytesize + content.bytesize / 4,
              encoding: content.encoding,
            )
          len = content.bytesize
          i = 0

          while i < len
            b = content.getbyte(i)

            case b
            when BACKSLASH # \
              if i + 1 < len && ascii_punctuation?(content.getbyte(i + 1))
                # Escape the backslash, but let the next char be processed on its own
                result << "\\\\"
                i += 1
              elsif i + 1 == len # backslash at end (hard break)
                result << "\\\\"
                i += 1
              else
                result << b
                i += 1
              end
            when DASH # -
              if i + 1 < len && content.getbyte(i + 1) == DASH
                # Consecutive dashes - escape each for Discourse ndash prevention
                while i < len && content.getbyte(i) == DASH
                  result << "\\-"
                  i += 1
                end
              else
                result << b
                i += 1
              end
            when TILDE # ~
              if i + 1 < len && content.getbyte(i + 1) == TILDE
                result << "\\~\\~"
                i += 2
              else
                result << b
                i += 1
              end
            when STAR # *
              while i < len && content.getbyte(i) == STAR
                result << "\\*"
                i += 1
              end
            when UNDERSCORE # _
              while i < len && content.getbyte(i) == UNDERSCORE
                result << "\\_"
                i += 1
              end
            when BACKTICK # `
              while i < len && content.getbyte(i) == BACKTICK
                result << "\\`"
                i += 1
              end
            when BANG # !
              if i + 1 < len && content.getbyte(i + 1) == BRACKET_OPEN
                result << "\\!\\["
                i += 2
              else
                result << b
                i += 1
              end
            when BRACKET_OPEN # [
              result << "\\["
              i += 1
            when PIPE # |
              result << "\\|"
              i += 1
            when LT # <
              remaining = content.byteslice(i, len - i)
              # Check for autolinks first - pass through entirely unchanged
              if (m = AUTOLINK.match(remaining))
                result << m[0]
                i += m[0].bytesize
                # Escape complete HTML tags (include tag in output for readability)
                # Also escape backticks inside the tag to prevent code span interpretation
              elsif (m = HTML_TAG.match(remaining))
                escaped_tag = m[0].gsub("`") { "\\`" }
                result << "\\" << escaped_tag
                i += m[0].bytesize
                # Escape HTML-like constructs: processing instructions, SGML declarations,
                # and potential tag starts (including multi-line and custom elements)
              elsif HTML_TAG_START.match?(remaining)
                result << "\\<"
                i += 1
              else
                # Not HTML-like (comparison operator, etc.)
                result << b
                i += 1
              end
            when AMP # &
              remaining = content.byteslice(i, len - i)
              if (m = ENTITY_REF.match(remaining))
                result << "\\" << m[0]
                i += m[0].bytesize
              else
                result << b
                i += 1
              end
            else
              # Regular character - handle multi-byte UTF-8
              if b < 128
                result << b
                i += 1
              else
                char_len = utf8_char_length(b)
                end_i = [i + char_len, len].min
                result << content.byteslice(i, end_i - i)
                i = end_i
              end
            end
          end

          result
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
          return false if line.empty?

          # Quick whitespace-only check
          first_non_space = 0
          while first_non_space < line.length && line.getbyte(first_non_space) == SPACE
            first_non_space += 1
          end
          return false if first_non_space >= line.length || line.getbyte(first_non_space) == TAB

          # Check if this is a block construct
          content = first_non_space <= 3 ? line[first_non_space..] : line
          return false if content.nil? || content.empty?

          first_byte = content.getbyte(0)

          case first_byte
          when HASH
            return false if ATX_HEADING.match?(content)
          when GT
            return false
          when DASH, PLUS, STAR
            return false if BULLET_LIST.match?(content)
            return false if first_byte == DASH && THEMATIC_BREAK_DASH.match?(content)
            return false if first_byte == STAR && THEMATIC_BREAK_STAR.match?(content)
          when UNDERSCORE
            return false if THEMATIC_BREAK_UNDERSCORE.match?(content)
          when BACKTICK, TILDE
            if FENCED_CODE_BACKTICK.match?(content) || FENCED_CODE_TILDE.match?(content)
              return false
            end
          when BRACKET_OPEN
            # Lines starting with [ get escaped to \[, which IS paragraph content
            # So setext headings CAN follow them
            return true
          when DIGIT_0..DIGIT_9
            return false if ORDERED_LIST.match?(content)
          end

          !INDENTED_CODE.match?(line)
        end
      end
    end
  end
end
