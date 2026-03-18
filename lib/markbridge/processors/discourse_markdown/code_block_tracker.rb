# frozen_string_literal: true

module Markbridge
  module Processors
    module DiscourseMarkdown
      # Tracks whether the current position is inside a code block.
      # Handles fenced code blocks (``` or ~~~), indented code blocks (4+ spaces),
      # and inline code (`).
      #
      # Fenced code blocks:
      # - Can have leading whitespace (up to 3 spaces)
      # - Opening fence: 3+ backticks or tildes, optionally followed by language
      # - Closing fence: same or more fence characters as opening
      #
      # Indented code blocks:
      # - Lines indented by 4+ spaces or 1+ tab
      # - Continues until a non-blank line with less indentation
      #
      # Inline code:
      # - Single or multiple backticks as delimiter
      # - Content between matching backticks
      class CodeBlockTracker
        # @return [Boolean] true if currently inside a fenced code block
        attr_reader :in_fenced_block

        # @return [Boolean] true if currently inside an indented code block
        attr_reader :in_indented_block

        # @return [Boolean] true if currently inside an inline code span
        attr_reader :in_inline_code

        def initialize
          @in_fenced_block = false
          @fence_char = nil
          @fence_length = 0
          @in_indented_block = false
          @in_inline_code = false
          @inline_delimiter = nil
        end

        # Check if currently inside any code context
        # @return [Boolean]
        def in_code?
          @in_fenced_block || @in_indented_block || @in_inline_code
        end

        # Check if position is at start of a fenced code block boundary
        # @param input [String] the full input string
        # @param pos [Integer] current position
        # @param line_start [Boolean] true if pos is at the start of a line
        # @return [Integer, nil] end position after fence, or nil if no fence
        def check_fenced_boundary(input, pos, line_start:)
          return nil unless line_start

          # Skip up to 3 spaces of indentation
          scan_pos = pos
          spaces = 0
          while spaces < 3 && scan_pos < input.length && input[scan_pos] == " "
            spaces += 1
            scan_pos += 1
          end

          return nil if scan_pos >= input.length

          fence_char = input[scan_pos]
          return nil unless fence_char == "`" || fence_char == "~"

          # Count consecutive fence characters
          fence_start = scan_pos
          fence_length = 0
          while scan_pos < input.length && input[scan_pos] == fence_char
            fence_length += 1
            scan_pos += 1
          end

          return nil if fence_length < 3

          if @in_fenced_block
            # Check if this closes the current block
            if fence_char == @fence_char && fence_length >= @fence_length
              # Closing fence - must be followed by newline or end of input
              # Skip any trailing whitespace
              scan_pos += 1 while scan_pos < input.length && input[scan_pos] == " "

              if scan_pos >= input.length || input[scan_pos] == "\n"
                @in_fenced_block = false
                @fence_char = nil
                @fence_length = 0
                # Return position after the newline if present
                return scan_pos < input.length ? scan_pos + 1 : scan_pos
              end
            end
            nil
          else
            # Opening fence - skip to end of line (info string)
            scan_pos += 1 while scan_pos < input.length && input[scan_pos] != "\n"

            @in_fenced_block = true
            @fence_char = fence_char
            @fence_length = fence_length

            # Return position after the newline if present
            scan_pos < input.length ? scan_pos + 1 : scan_pos
          end
        end

        # Check if line at position is an indented code block line.
        # A line is considered indented code if it starts with 4+ spaces or 1+ tab.
        # Blank lines within an indented block are considered part of it.
        #
        # @param input [String] the full input string
        # @param pos [Integer] current position (must be at line start)
        # @param line_start [Boolean] true if pos is at the start of a line
        # @return [Integer, nil] end position after the line, or nil if not indented code
        def check_indented_boundary(input, pos, line_start:)
          return nil unless line_start
          return nil if @in_fenced_block # Fenced blocks take precedence

          # Find end of line
          line_end = input.index("\n", pos) || input.length

          # Check if line is blank
          line_content = input[pos...line_end]
          is_blank = line_content.match?(/\A\s*\z/)

          # Check indentation (4+ spaces or tab)
          has_code_indent = line_content.start_with?("    ") || line_content.start_with?("\t")

          if @in_indented_block
            if is_blank
              # Blank lines continue the indented block
              # Return end of line (after newline if present)
              return line_end < input.length ? line_end + 1 : line_end
            elsif has_code_indent
              # Still in indented code
              return line_end < input.length ? line_end + 1 : line_end
            else
              # Non-blank, non-indented line ends the block
              @in_indented_block = false
              return nil
            end
          else
            if has_code_indent
              # Start of indented code block
              @in_indented_block = true
              return line_end < input.length ? line_end + 1 : line_end
            end
          end

          nil
        end

        # Check for inline code boundary
        # @param input [String] the full input string
        # @param pos [Integer] current position
        # @return [Integer, nil] end position after inline code, or nil if not at boundary
        def check_inline_boundary(input, pos)
          return nil if @in_fenced_block || @in_indented_block
          return nil if pos >= input.length || input[pos] != "`"

          if @in_inline_code
            # Check if this closes the current inline code
            delimiter_length = @inline_delimiter.length
            if input[pos, delimiter_length] == @inline_delimiter
              # Check what follows - should not be another backtick
              next_pos = pos + delimiter_length
              if next_pos >= input.length || input[next_pos] != "`"
                @in_inline_code = false
                @inline_delimiter = nil
                return next_pos
              end
            end
            nil
          else
            # Opening inline code - count backticks
            delimiter_start = pos
            pos += 1 while pos < input.length && input[pos] == "`"

            @inline_delimiter = input[delimiter_start...pos]
            @in_inline_code = true

            # Return position after opening delimiter
            pos
          end
        end

        # Reset the tracker state
        def reset!
          @in_fenced_block = false
          @fence_char = nil
          @fence_length = 0
          @in_indented_block = false
          @in_inline_code = false
          @inline_delimiter = nil
        end
      end
    end
  end
end
