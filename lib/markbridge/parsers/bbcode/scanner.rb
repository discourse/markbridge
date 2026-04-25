# frozen_string_literal: true

module Markbridge
  module Parsers
    module BBCode
      # High-performance character-by-character BBCode scanner
      # Tokenizes BBCode in O(n) time with minimal allocations and bounded backtracking
      class Scanner
        def initialize(input)
          @input = input
          @length = input.length
          @current_pos = 0
        end

        def next_token
          return nil if end_of_input?
          start_pos = @current_pos
          bracket_index = @input.index("[", @current_pos)

          if bracket_index.nil?
            text = @input[@current_pos..]
            @current_pos = @length
            TextToken.new(text:, pos: start_pos)
          elsif bracket_index > @current_pos
            text = @input[@current_pos...bracket_index]
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

        TAG_INITIAL_CHAR = /[a-z*]/i
        TAG_NAME_CHAR = /[a-z0-9]/i
        UID_HEX_CHAR = /[0-9a-f]/i
        ATTR_NAME_CHAR = /\w/
        WHITESPACE_CHAR = /\s/
        UNQUOTED_VALUE_STOP = /[\[\]\s]/

        private_constant :TAG_INITIAL_CHAR,
                         :TAG_NAME_CHAR,
                         :UID_HEX_CHAR,
                         :ATTR_NAME_CHAR,
                         :WHITESPACE_CHAR,
                         :UNQUOTED_VALUE_STOP

        # @return [Token, nil] tag token or nil if not a valid tag (caller rolls back)
        # Precondition: caller has verified current_char == "[".
        def parse_tag_at_cursor
          tag_start_pos = @current_pos
          @current_pos += 1 # skip '['
          closing = consume("/")
          tag_name = scan_tag_name
          attrs = (closing || tag_name.nil?) ? {} : scan_attributes
          return rollback(tag_start_pos) unless tag_name && consume("]")

          source = @input[tag_start_pos...@current_pos]
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

        # Scan a tag name: [a-z*][a-z0-9]*(:hex*)?
        #
        # Char-by-char rather than a single regex over `@input[pos..]`
        # because the regex form allocates a substring for every tag,
        # which is a dominant cost on tag-heavy input. The char-based
        # loop is ~3x faster under YJIT.
        # @return [String, nil]
        def scan_tag_name
          start = @current_pos

          return nil unless current_char&.match?(TAG_INITIAL_CHAR)
          @current_pos += 1

          @current_pos += 1 while current_char&.match?(TAG_NAME_CHAR)

          if current_char == ":"
            @current_pos += 1
            @current_pos += 1 while current_char&.match?(UID_HEX_CHAR)
          end

          @input[start...@current_pos]
        end

        # Scan tag attributes
        # The first `=value` (if present) becomes the `:option` attribute
        # Additional `key=value` pairs become named attributes
        # @return [Hash]
        def scan_attributes
          attrs = {}
          skip_whitespace

          if current_char == "="
            @current_pos += 1
            skip_whitespace
            if (val = scan_attribute_value)
              attrs[:option] = val
            end
            skip_whitespace
          end

          while (name = scan_while(ATTR_NAME_CHAR))
            skip_whitespace
            break unless consume("=")

            skip_whitespace
            value = scan_attribute_value
            attrs[name.downcase.to_sym] = value if value
            skip_whitespace
          end

          attrs
        end

        def consume(char)
          return false if current_char != char

          @current_pos += 1
          true
        end

        def scan_attribute_value
          char = current_char
          if char == '"' || char == "'"
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
          quote_char = current_char
          start = (@current_pos += 1) # skip opening quote
          closing_index = @input.index(quote_char, start)
          return nil unless closing_index

          @current_pos = closing_index + 1
          @input[start...closing_index]
        end

        def scan_unquoted_value
          scan_until(UNQUOTED_VALUE_STOP)
        end

        # Consumes characters matching +pattern+; returns substring or nil if empty
        def scan_while(pattern)
          stop_index = @current_pos
          stop_index += 1 while stop_index < @length && @input[stop_index].match?(pattern)
          consume_range(stop_index)
        end

        # Consumes characters until +pattern+ matches (or end of input); returns substring or nil if empty
        def scan_until(pattern)
          consume_range(@input.index(pattern, @current_pos) || @length)
        end

        # Slice [@current_pos, stop_index), advance the cursor, or return nil for empty.
        def consume_range(stop_index)
          return nil if stop_index == @current_pos

          value = @input[@current_pos...stop_index]
          @current_pos = stop_index
          value
        end

        def current_char
          @input[@current_pos]
        end

        def skip_whitespace
          @current_pos += 1 while @current_pos < @length &&
            @input[@current_pos].match?(WHITESPACE_CHAR)
        end

        def end_of_input?
          # All callers maintain @current_pos <= @length (scan_while
          # bounds on @length; scan_until uses `index || @length`;
          # consume is a no-op at EOF); `==` and `>=` are observably
          # identical here.
          @current_pos == @length
        end
      end
    end
  end
end
