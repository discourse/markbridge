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
            return TextToken.new(text:, pos: start_pos)
          end

          if bracket_index > @current_pos
            text = @input[@current_pos...bracket_index]
            @current_pos = bracket_index
            return TextToken.new(text:, pos: start_pos)
          end

          if (tag_token = parse_tag_at_cursor)
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

        def parse_tag_at_cursor
          return nil if current_char != "["

          tag_start_pos = @current_pos
          @current_pos += 1 # skip '['

          # Check for closing tag
          closing = current_char == "/"
          @current_pos += 1 if closing

          # Parse tag name
          tag_name = scan_tag_name
          return rollback(tag_start_pos) unless tag_name

          # Parse attributes (only for opening tags)
          attrs = closing ? {} : scan_attributes
          return rollback(tag_start_pos) if current_char != "]"

          @current_pos += 1 # skip ']'

          # Capture original source text
          source = @input[tag_start_pos...@current_pos]

          normalized_tag_name = tag_name.downcase

          if closing
            TagEndToken.new(tag: normalized_tag_name, pos: tag_start_pos, source:)
          else
            TagStartToken.new(tag: normalized_tag_name, attrs:, pos: tag_start_pos, source:)
          end
        end

        def rollback(pos)
          @current_pos = pos
          nil
        end

        # Scan a tag name: [a-z*.][a-z0-9]*(:uid)?
        # @return [String, nil]
        def scan_tag_name
          start = @current_pos

          # First character: letter, *, or .
          return nil unless current_char&.match?(TAG_INITIAL_CHAR)
          @current_pos += 1

          # Remaining characters: letters or digits
          @current_pos += 1 while current_char&.match?(TAG_NAME_CHAR)

          # Optional :uid suffix (e.g., [quote:abc123])
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

          # First attribute might be option: [tag=value]
          if current_char == "="
            @current_pos += 1
            skip_whitespace
            if (val = scan_attribute_value)
              attrs[:option] = val
            end
            skip_whitespace
          end

          # Named attributes: [tag key=value key=value ...]
          while (char = current_char) && char != "]"
            name = scan_while(ATTR_NAME_CHAR)
            break if name.nil?

            skip_whitespace
            break if current_char != "="

            @current_pos += 1
            skip_whitespace

            value = scan_attribute_value
            attrs[name.downcase.to_sym] = value if value
            skip_whitespace
          end

          attrs
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
        # @return [String] the unescaped attribute value
        def scan_quoted_string
          quote_char = current_char
          start = (@current_pos += 1) # skip opening quote

          closing_index = @input.index(quote_char, start)

          if closing_index
            value = @input[start...closing_index]
            @current_pos = closing_index + 1 # position after closing quote
          else
            value = @input[start..] || ""
            @current_pos = @length
          end

          value
        end

        def scan_unquoted_value
          scan_until(UNQUOTED_VALUE_STOP)
        end

        # Consumes characters matching +pattern+; returns substring or nil if empty
        def scan_while(pattern)
          start = @current_pos
          while (char = current_char) && char.match?(pattern)
            @current_pos += 1
          end

          return nil if @current_pos == start
          @input[start...@current_pos]
        end

        # Consumes characters until +pattern+ matches; returns substring or nil if empty
        def scan_until(pattern)
          stop_index = @input.index(pattern, @current_pos) || @length
          return nil if stop_index == @current_pos

          value = @input[@current_pos...stop_index]
          @current_pos = stop_index
          value
        end

        def current_char
          @input[@current_pos]
        end

        def skip_whitespace
          @current_pos += 1 while current_char&.match?(WHITESPACE_CHAR)
        end

        def end_of_input?
          @current_pos >= @length
        end
      end
    end
  end
end
