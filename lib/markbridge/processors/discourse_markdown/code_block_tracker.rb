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
          @in_indented_block = false
          @in_inline_code = false
          # @fence_char / @fence_length / @inline_delimiter are set by
          # open_fence / open_inline before any helper reads them;
          # they're only consulted when the corresponding in_X flag is
          # true, which requires a prior open_* call.
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

          input_length = input.length
          scan_pos = skip_leading_spaces(input, pos, input_length)
          return nil if scan_pos >= input_length

          fence_char = input[scan_pos]
          return nil unless fence_char == "`" || fence_char == "~"

          fence_length, scan_pos = count_fence_chars(input, scan_pos, fence_char, input_length)
          return nil if fence_length < 3

          if @in_fenced_block
            try_close_fence(input, scan_pos, fence_char, fence_length, input_length)
          else
            open_fence(input, scan_pos, fence_char, fence_length, input_length)
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

          input_length = input.length
          line_end = input.index("\n", pos) || input_length
          line_content = input[pos...line_end]
          is_blank = line_content.match?(/\A\s*\z/)
          has_code_indent = line_content.start_with?("    ") || line_content.start_with?("\t")

          if @in_indented_block
            if is_blank || has_code_indent
              pos_after_line(line_end, input_length)
            else
              @in_indented_block = false
              nil
            end
          elsif has_code_indent
            @in_indented_block = true
            pos_after_line(line_end, input_length)
          end
        end

        # Check for inline code boundary
        # @param input [String] the full input string
        # @param pos [Integer] current position
        # @return [Integer, nil] end position after inline code, or nil if not at boundary
        def check_inline_boundary(input, pos)
          return nil if @in_fenced_block || @in_indented_block

          input_length = input.length
          return nil if pos >= input_length || input[pos] != "`"

          if @in_inline_code
            try_close_inline(input, pos, input_length)
          else
            open_inline(input, pos, input_length)
          end
        end

        private

        # Skip up to 3 leading spaces of indentation.
        #
        # All five compound `while A && B` loops in this file are split into
        # `while <bound>` + `break if …` to dodge a Ruby 3.4.8 PRISM VM bug
        # (https://bugs.ruby-lang.org/issues/22002, fixed in 3.4.10).
        def skip_leading_spaces(input, pos, input_length)
          scan_pos = pos
          spaces = 0
          while spaces < 3
            break if scan_pos >= input_length
            break if input[scan_pos] != " "
            spaces += 1
            scan_pos += 1
          end
          scan_pos
        end

        # Count consecutive fence characters and return [count, new_position].
        def count_fence_chars(input, scan_pos, fence_char, input_length)
          fence_length = 0
          while scan_pos < input_length
            break if input[scan_pos] != fence_char
            fence_length += 1
            scan_pos += 1
          end
          [fence_length, scan_pos]
        end

        # Try to close an open fenced code block. Returns position after fence or nil.
        def try_close_fence(input, scan_pos, fence_char, fence_length, input_length)
          return nil unless fence_char == @fence_char && fence_length >= @fence_length

          # Closing fence must be followed only by spaces then newline/EOF
          while scan_pos < input_length
            break if input[scan_pos] != " "
            scan_pos += 1
          end
          return nil unless scan_pos >= input_length || input[scan_pos] == "\n"

          @in_fenced_block = false
          @fence_char = nil
          @fence_length = 0
          pos_after_line(scan_pos, input_length)
        end

        # Open a new fenced code block. Returns position after the opening line.
        def open_fence(input, scan_pos, fence_char, fence_length, input_length)
          # Skip to end of line (info string)
          while scan_pos < input_length
            break if input[scan_pos] == "\n"
            scan_pos += 1
          end

          @in_fenced_block = true
          @fence_char = fence_char
          @fence_length = fence_length
          pos_after_line(scan_pos, input_length)
        end

        # Try to close inline code. Returns position after delimiter or nil.
        def try_close_inline(input, pos, input_length)
          delimiter_length = @inline_delimiter.length
          return nil unless input[pos, delimiter_length] == @inline_delimiter

          # Should not be followed by another backtick
          next_pos = pos + delimiter_length
          return nil if next_pos < input_length && input[next_pos] == "`"

          @in_inline_code = false
          @inline_delimiter = nil
          next_pos
        end

        # Open inline code. Returns position after opening delimiter.
        def open_inline(input, pos, input_length)
          delimiter_start = pos
          while pos < input_length
            break if input[pos] != "`"
            pos += 1
          end

          @inline_delimiter = input[delimiter_start...pos]
          @in_inline_code = true
          pos
        end

        # Return position after a line (after newline if present, otherwise at end).
        def pos_after_line(line_end, input_length)
          line_end < input_length ? line_end + 1 : line_end
        end

        public

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
