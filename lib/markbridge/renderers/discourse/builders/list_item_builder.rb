# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Builders
        # Builder for list item formatting
        # Handles complex multi-line formatting with proper indentation
        # and preservation of blank lines and nested list items
        class ListItemBuilder
          # Build a formatted list item string
          # @param content [String] the item content
          # @param marker [String] the list marker ("- " or "1. ")
          # @param indent [String] the indentation string
          # @return [String]
          def build(content, marker:, indent:)
            lines = content.split("\n")
            first_line = "#{indent}#{marker}#{lines.first}"

            return "#{first_line}\n" if lines.size < 2

            format_multiline(lines, first_line, indent)
          end

          private

          # Format multi-line content with proper indentation
          # @param lines [Array<String>] content lines
          # @param first_line [String] the formatted first line
          # @param indent [String] base indentation
          # @return [String]
          def format_multiline(lines, first_line, indent)
            continuation_indent = "#{indent}  "
            continuation_lines = lines[1..]

            rest =
              continuation_lines.each_with_index.filter_map do |line, idx|
                format_continuation_line(line, idx, continuation_lines, continuation_indent)
              end

            "#{([first_line] + rest).join("\n")}\n"
          end

          # Format a single continuation line
          # @param line [String] the line to format
          # @param idx [Integer] index in continuation_lines array
          # @param continuation_lines [Array<String>] all continuation lines
          # @param continuation_indent [String] indent for continuation
          # @return [String, nil] formatted line or nil to skip
          def format_continuation_line(line, idx, continuation_lines, continuation_indent)
            # Handle empty lines
            return handle_empty_line(idx, continuation_lines, continuation_indent) if line.empty?

            # Check if line is already a list item (has indentation + marker)
            if line.match?(/\A\s*(?:-|\d+\.)\s/)
              # Already a list item - don't add extra indentation
              line
            else
              # Regular continuation line - add indentation
              "#{continuation_indent}#{line}"
            end
          end

          # Handle empty lines in continuation. Caller (format_continuation_line)
          # only invokes this when `line.empty?`, and `content.split("\n")`
          # trims trailing empty strings, so the LAST continuation line is
          # never empty — `idx + 1` is always in bounds when we get here.
          # @param idx [Integer] index in continuation_lines
          # @param continuation_lines [Array<String>] all continuation lines
          # @param continuation_indent [String] indent for continuation
          # @return [String, nil] formatted line or nil to skip
          def handle_empty_line(idx, continuation_lines, continuation_indent)
            # Skip empty lines that come before nested list items (structural blanks)
            return nil if continuation_lines[idx + 1].match?(/\A\s*(?:-|\d+\.)\s/)

            # Preserve empty lines within text content (paragraph breaks) with indentation
            continuation_indent
          end
        end
      end
    end
  end
end
