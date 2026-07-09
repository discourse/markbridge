# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # High-performance BBCode scanner
      # Tokenizes BBCode in O(n) time with minimal allocations and bounded backtracking
      #
      # The scanner works entirely in *byte* offsets (byteindex/byteslice/
      # getbyte). CRuby has no character-index cache, so character-index
      # operations like `str[pos]` walk the string from the start on any
      # input containing a multibyte character — O(pos) per call and
      # superlinear per document. Byte offsets keep multibyte input at
      # near-ASCII cost. Invariant: `@current_pos` always sits on a
      # character boundary — jumps land on matches of ASCII-only patterns
      # and advances step over ASCII bytes or whole matches. Token
      # positions are therefore byte offsets into the input.
      class Scanner
        def initialize(input)
          @input = input
          @length = input.bytesize
          @current_pos = 0
        end

        def next_token
          return nil if end_of_input?
          start_pos = @current_pos
          # `byteindex` returns 0 for a match at the start — nil-check, never
          # truthiness-check. Can't be 0 here though: callers guarantee
          # @current_pos <= bracket_index.
          bracket_index = @input.byteindex("[", @current_pos)

          if bracket_index.nil?
            text = @input.byteslice(@current_pos, @length - @current_pos)
            @current_pos = @length
            TextToken.new(text:, pos: start_pos)
          elsif bracket_index > @current_pos
            text = @input.byteslice(@current_pos, bracket_index - @current_pos)
            @current_pos = bracket_index
            TextToken.new(text:, pos: start_pos)
          elsif (tag_token = parse_tag_at_cursor)
            tag_token
          else
            @current_pos += 1
            TextToken.new(text: "[", pos: start_pos)
          end
        end

        private

        # Byte constants for tag scanning. A byte >= 0x80 (multibyte
        # lead/continuation) never satisfies any of the ASCII predicates
        # below, so no encoding-awareness is needed at probe sites.
        TAB = 9 # \t
        CR = 13 # \r  (\s == [ \t\n\v\f\r] == 0x20, 0x09..0x0D)
        SPACE = 32
        DOUBLE_QUOTE = 34 # "
        SINGLE_QUOTE = 39 # '
        STAR = 42 # *
        SLASH = 47 # /
        DIGIT_0 = 48
        DIGIT_9 = 57
        COLON = 58 # :
        EQUALS = 61 # =
        UPPER_A = 65
        UPPER_F = 70
        UPPER_Z = 90
        BRACKET_CLOSE = 93 # ]
        UNDERSCORE = 95 # _
        LOWER_A = 97
        LOWER_F = 102
        LOWER_Z = 122

        # Characters an unquoted attribute value stops at. ASCII-only, so a
        # byteindex match always lands on a character boundary.
        UNQUOTED_VALUE_STOP = /[\[\]\s]/

        private_constant :TAB,
                         :CR,
                         :SPACE,
                         :DOUBLE_QUOTE,
                         :SINGLE_QUOTE,
                         :STAR,
                         :SLASH,
                         :DIGIT_0,
                         :DIGIT_9,
                         :COLON,
                         :EQUALS,
                         :UPPER_A,
                         :UPPER_F,
                         :UPPER_Z,
                         :BRACKET_CLOSE,
                         :UNDERSCORE,
                         :LOWER_A,
                         :LOWER_F,
                         :LOWER_Z,
                         :UNQUOTED_VALUE_STOP

        # @return [Token, nil] tag token or nil if not a valid tag (caller rolls back)
        # Precondition: caller has verified the byte at the cursor is "[".
        def parse_tag_at_cursor
          tag_start_pos = @current_pos
          @current_pos += 1 # skip '['
          closing = consume(SLASH)
          tag_name = scan_tag_name
          attrs = (closing || tag_name.nil?) ? {} : scan_attributes
          return rollback(tag_start_pos) unless tag_name && consume(BRACKET_CLOSE)

          source = @input.byteslice(tag_start_pos, @current_pos - tag_start_pos)
          build_token(closing:, tag: tag_name.downcase, attrs:, pos: tag_start_pos, source:)
        end

        def build_token(closing:, tag:, attrs:, pos:, source:)
          if closing
            TagEndToken.new(tag:, pos:, source:)
          else
            TagStartToken.new(tag:, attrs:, pos:, source:)
          end
        end

        def rollback(pos)
          @current_pos = pos
          nil
        end

        # Scan a tag name: [a-z*][a-z0-9]*(:hex*)?  (case-insensitive)
        #
        # Byte-predicate loop rather than a regex over `@input[pos..]`
        # because the regex form allocates a substring for every tag,
        # which is a dominant cost on tag-heavy input.
        # @return [String, nil]
        def scan_tag_name
          start = @current_pos

          return nil unless tag_initial_byte?(current_byte)
          @current_pos += 1

          @current_pos += 1 while tag_name_byte?(current_byte)

          if current_byte == COLON
            @current_pos += 1
            @current_pos += 1 while uid_hex_byte?(current_byte)
          end

          @input.byteslice(start, @current_pos - start)
        end

        # Scan tag attributes
        # The first `=value` (if present) becomes the `:option` attribute
        # Additional `key=value` pairs become named attributes
        # @return [Hash]
        def scan_attributes
          attrs = {}
          skip_whitespace

          if current_byte == EQUALS
            @current_pos += 1
            skip_whitespace
            if (val = scan_attribute_value)
              attrs[:option] = val
            end
            skip_whitespace
          end

          while (name = scan_attr_name)
            skip_whitespace
            break unless consume(EQUALS)

            skip_whitespace
            value = scan_attribute_value
            attrs[name.downcase.to_sym] = value if value
            skip_whitespace
          end

          attrs
        end

        def consume(byte)
          return false if current_byte != byte

          @current_pos += 1
          true
        end

        def scan_attribute_value
          byte = current_byte
          if byte == DOUBLE_QUOTE || byte == SINGLE_QUOTE
            scan_quoted_string
          else
            scan_unquoted_value
          end
        end

        # Scans a quoted attribute value (double or single quoted)
        #
        # IMPORTANT: This method does NOT support escape sequences (e.g., \" or \\).
        # This is intentional - standard BBCode does not define escape syntax.
        # The scanner stops at the first matching quote character.
        #
        # Examples:
        #   [url="http://example.com"]     → option: "http://example.com" ✓
        #   [url='single quotes']          → option: "single quotes" ✓
        #   [url="has \"quotes\" inside"]  → FAILS (stops at first inner quote) ✗
        #
        # Workaround: Use single quotes if you need double quotes in the value:
        #   [url='has "quotes" inside']    → option: "has \"quotes\" inside" ✓
        #
        # @return [String, nil] the unescaped attribute value, or nil if unterminated
        def scan_quoted_string
          quote = current_byte == DOUBLE_QUOTE ? "\"" : "'"
          start = (@current_pos += 1) # skip opening quote
          closing_index = @input.byteindex(quote, start)
          return nil unless closing_index

          @current_pos = closing_index + 1
          @input.byteslice(start, closing_index - start)
        end

        def scan_unquoted_value
          consume_range(@input.byteindex(UNQUOTED_VALUE_STOP, @current_pos) || @length)
        end

        # Consumes attribute-name characters (\w == [A-Za-z0-9_]); returns
        # substring or nil if empty
        def scan_attr_name
          stop_index = @current_pos
          stop_index += 1 while stop_index < @length && attr_name_byte?(@input.getbyte(stop_index))
          consume_range(stop_index)
        end

        # Slice [@current_pos, stop_index), advance the cursor, or return nil for empty.
        def consume_range(stop_index)
          return nil if stop_index == @current_pos

          value = @input.byteslice(@current_pos, stop_index - @current_pos)
          @current_pos = stop_index
          value
        end

        # @return [Integer, nil] byte at the cursor, nil at end of input
        def current_byte
          @input.getbyte(@current_pos)
        end

        def skip_whitespace
          @current_pos += 1 while @current_pos < @length &&
            whitespace_byte?(@input.getbyte(@current_pos))
        end

        # [a-z*]/i — first character of a tag name; nil (end of input) is
        # not a tag byte
        def tag_initial_byte?(byte)
          byte &&
            (
              (byte >= LOWER_A && byte <= LOWER_Z) || (byte >= UPPER_A && byte <= UPPER_Z) ||
                byte == STAR
            )
        end

        # [a-z0-9]/i — rest of a tag name
        def tag_name_byte?(byte)
          return false if byte.nil?

          (byte >= LOWER_A && byte <= LOWER_Z) || (byte >= UPPER_A && byte <= UPPER_Z) ||
            (byte >= DIGIT_0 && byte <= DIGIT_9)
        end

        # [0-9a-f]/i — uid suffix after ':'
        def uid_hex_byte?(byte)
          return false if byte.nil?

          (byte >= DIGIT_0 && byte <= DIGIT_9) || (byte >= LOWER_A && byte <= LOWER_F) ||
            (byte >= UPPER_A && byte <= UPPER_F)
        end

        # \w — attribute name character
        def attr_name_byte?(byte)
          (byte >= LOWER_A && byte <= LOWER_Z) || (byte >= UPPER_A && byte <= UPPER_Z) ||
            (byte >= DIGIT_0 && byte <= DIGIT_9) || byte == UNDERSCORE
        end

        # \s — exactly [ \t\n\v\f\r]
        def whitespace_byte?(byte)
          byte == SPACE || (byte >= TAB && byte <= CR)
        end

        def end_of_input?
          # All callers maintain @current_pos <= @length (scan_attr_name
          # bounds on @length; scan_unquoted_value uses `byteindex || @length`;
          # consume is a no-op at EOF); `==` and `>=` are observably
          # identical here.
          @current_pos == @length
        end
      end
    end
  end
end
