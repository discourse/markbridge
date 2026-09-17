# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Builders
        # Builder for list item formatting
        # Handles complex multi-line formatting with proper indentation
        # and preservation of blank lines and nested list items
        class ListItemBuilder
          # A line already carrying a list marker.
          LIST_MARKER = /\A\s*(?:-|\d+\.)\s/
          # Block tag names of a CommonMark type 6 HTML block (spec 4.6).
          # Order is irrelevant: the delimiter the pattern requires after
          # the name is what stops `<p>` matching `<paragraph>`.
          HTML_BLOCK_TAGS = %w[
            blockquote
            figcaption
            colgroup
            fieldset
            menuitem
            noframes
            optgroup
            frameset
            section
            details
            summary
            caption
            address
            article
            basefont
            dialog
            iframe
            legend
            option
            search
            footer
            header
            figure
            frame
            param
            track
            title
            thead
            tbody
            tfoot
            table
            aside
            base
            body
            center
            col
            dd
            dir
            div
            dl
            dt
            form
            h1
            h2
            h3
            h4
            h5
            h6
            head
            hr
            html
            li
            link
            main
            menu
            nav
            ol
            p
            td
            th
            tr
            ul
          ].freeze

          # A line that starts an HTML block: `<` or `</`, one of the tag
          # names above, then a space, tab, `>`, `/>` or end of line.
          # CommonMark ends such a block at the next blank line, so
          # handle_empty_line keeps that blank instead of dropping it.
          #
          # `</div>` starts a block just as `<div>` does. Drop the blank
          # after an aligned block's closing tag and a nested list below it
          # renders as plain text. The tag name matters too.
          # `<https://example.com>` and `<span ...>red</span>` start
          # nothing, and a blank kept after one of those puts a paragraph
          # around every item of the surrounding list.
          HTML_BLOCK_OPENER =
            %r{\A[ \t]*</?(?:#{Regexp.union(HTML_BLOCK_TAGS).source})(?:[ \t>]|/>|\z)}i
          # A line that opens a fenced code block. The markers in front are
          # optional because a nested item can begin with a fence, which
          # reaches here as `- ``` `. If that opener is missed, the block's
          # closing fence is taken for an opening one, and every line after
          # the block is then treated as code.
          CODE_FENCE_OPEN = /\A[ \t]*(?:(?:-|\d+\.)[ \t]+)*(?:(`{3,})|(~{3,}))/
          # A line that closes one: the delimiter run on its own. A line
          # with a marker in front of it never closes a block, and neither
          # does a ```ruby line inside a ~~~ block (CommonMark 4.5).
          CODE_FENCE_CLOSE = /\A[ \t]*(?:(`{3,})|(~{3,}))[ \t]*\z/
          private_constant :LIST_MARKER,
                           :HTML_BLOCK_TAGS,
                           :HTML_BLOCK_OPENER,
                           :CODE_FENCE_OPEN,
                           :CODE_FENCE_CLOSE

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

            # The fenced code block being copied, or nil when outside one.
            # Its lines get the same prefix the opening fence got, so the
            # code keeps its own indentation. `build` has already moved the
            # item's first line into first_line, so check that line here.
            fence = fence_opened_by(lines.first, continuation_indent)

            rest =
              continuation_lines.each_with_index.filter_map do |line, idx|
                # Leading spaces inside a fence belong to the code rather
                # than the layout, so the checks below are skipped here.
                unless fence.nil?
                  length, backticks, placed = fence
                  fence = nil if closes_fence?(line, length, backticks)
                  next(placed ? line : "#{continuation_indent}#{line}")
                end

                # Only reached outside a fence, so never clears an open one.
                fence = fence_opened_by(line, continuation_indent)

                # continuation_lines is lines[1..], so lines[idx] precedes it.
                format_continuation_line(
                  line,
                  idx,
                  continuation_lines,
                  continuation_indent,
                  lines[idx],
                )
              end

            "#{([first_line] + rest).join("\n")}\n"
          end

          # Format a single continuation line
          # @param line [String] the line to format
          # @param idx [Integer] index in continuation_lines array
          # @param continuation_lines [Array<String>] all continuation lines
          # @param continuation_indent [String] indent for continuation
          # @param previous_line [String] the raw line before this one
          # @return [String, nil] formatted line or nil to skip
          def format_continuation_line(
            line,
            idx,
            continuation_lines,
            continuation_indent,
            previous_line
          )
            # Handle empty lines
            if line.empty?
              return handle_empty_line(idx, continuation_lines, continuation_indent, previous_line)
            end

            # These lines are already at the column they belong in, because
            # a nested build put them there. Indenting them again moves them
            # out of step with the lines around them: an aligned block's
            # `</div>` pushed one level too deep ends up inside the last
            # list item and breaks the HTML. Text can arrive indented too,
            # but never by enough to change how Markdown reads it. Code can,
            # and format_multiline handles it before this method runs.
            if line.match?(LIST_MARKER) || already_placed?(line, continuation_indent)
              line
            else
              # Regular continuation line - add indentation
              "#{continuation_indent}#{line}"
            end
          end

          # The fence state +line+ opens, or nil when it opens none.
          # @param line [String]
          # @param continuation_indent [String]
          # @return [Array(Integer, String, Boolean), nil] run length, the
          #   run itself when backticks (nil for tildes), already placed?
          def fence_opened_by(line, continuation_indent)
            match = CODE_FENCE_OPEN.match(line)
            return nil unless match

            backticks = match[1]
            # A backtick fence cannot carry a backtick after its opening
            # run (CommonMark 4.5). That is what stops an inline ```span```
            # on a list-item line being read as a fence.
            return nil if backticks && match.post_match.include?("`")

            [(backticks || match[2]).length, backticks, already_placed?(line, continuation_indent)]
          end

          # Whether +line+ closes a block opened by a run of +length+. The
          # capture groups keep backtick and tilde runs apart, so only the
          # delimiter that opened the block can close it.
          # @param line [String]
          # @param length [Integer] length of the opening run
          # @param backticks [String, nil] opening run when backticks
          # @return [Boolean]
          def closes_fence?(line, length, backticks)
            match = CODE_FENCE_CLOSE.match(line)
            return false unless match

            run = backticks ? match[1] : match[2]
            return false if run.nil?

            run.length >= length
          end

          # Whether a nested build already placed this line, so re-indenting
          # would push it a level too deep.
          # @param line [String]
          # @param continuation_indent [String]
          # @return [Boolean]
          def already_placed?(line, continuation_indent)
            line.start_with?(continuation_indent)
          end

          # Handle empty lines in continuation. Caller (format_continuation_line)
          # only invokes this when `line.empty?`, and `content.split("\n")`
          # trims trailing empty strings, so the LAST continuation line is
          # never empty — `idx + 1` is always in bounds when we get here.
          # @param idx [Integer] index in continuation_lines
          # @param continuation_lines [Array<String>] all continuation lines
          # @param continuation_indent [String] indent for continuation
          # @param previous_line [String] the raw line before this blank
          # @return [String, nil] formatted line or nil to skip
          def handle_empty_line(idx, continuation_lines, continuation_indent, previous_line)
            # Keep a blank line that ends an open HTML block. Without it the
            # list below stays inside the block and renders as plain text.
            return continuation_indent if previous_line.match?(HTML_BLOCK_OPENER)

            # Skip empty lines that come before nested list items (structural blanks)
            return nil if continuation_lines[idx + 1].match?(LIST_MARKER)

            # Preserve empty lines within text content (paragraph breaks) with indentation
            continuation_indent
          end
        end
      end
    end
  end
end
