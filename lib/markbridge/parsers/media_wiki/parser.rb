# frozen_string_literal: true

module Markbridge
  module Parsers
    module MediaWiki
      # Parses MediaWiki wikitext into an AST.
      #
      # Supports:
      # - Bold ('''), italic (''), bold italic (''''')
      # - Headings (= through ======)
      # - Unordered lists (* / ** / ***)
      # - Ordered lists (# / ## / ###)
      # - Horizontal rules (----)
      # - Internal links ([[target]] / [[target|display]])
      # - External links ([url text])
      # - Preformatted text (lines starting with a space)
      # - Tables ({| ... |})
      # - HTML tags: <nowiki>, <code>, <pre>, <br>, <s>, <del>, <u>, <ins>, <sup>, <sub>
      #
      # @example Basic usage
      #   parser = Markbridge::Parsers::MediaWiki::Parser.new
      #   ast = parser.parse("'''bold''' and ''italic''")
      class Parser
        # @param inline_tag_registry [InlineTagRegistry, nil] custom registry or use default
        # @yield [InlineTagRegistry] optional block to customize the default registry
        def initialize(inline_tag_registry: nil, &block)
          @inline_tag_registry =
            if block_given?
              InlineTagRegistry.build_from_default(&block)
            else
              inline_tag_registry || InlineTagRegistry.default
            end
          @document = nil
          @inline_parser = nil
          @list_stack = []
        end

        # Parse MediaWiki wikitext into an AST Document.
        #
        # @param input [String] MediaWiki source
        # @return [AST::Document]
        def parse(input)
          normalized = normalize_line_endings(input)
          lines = normalized.split("\n", -1)

          @document = AST::Document.new
          @inline_parser = InlineParser.new(inline_tag_registry: @inline_tag_registry)
          @list_stack = []

          process_lines(lines)
          close_open_lists
          @document
        end

        private

        # Normalize line endings (CR, CRLF, and Unicode separators).
        #
        # @param input [String]
        # @return [String]
        def normalize_line_endings(input)
          input.gsub(/\r\n?|[\u2028\u2029]+/, "\n")
        end

        # Process all lines of input.
        #
        # @param lines [Array<String>]
        def process_lines(lines)
          i = 0
          while i < lines.length
            line = lines[i]

            if heading_line?(line)
              close_open_lists
              process_heading(line)
            elsif horizontal_rule_line?(line)
              close_open_lists
              @document << AST::HorizontalRule.new
            elsif table_start_line?(line)
              close_open_lists
              i = process_table(lines, i)
            elsif list_line?(line)
              process_list_item(line)
            elsif preformatted_line?(line)
              close_open_lists
              i = process_preformatted_block(lines, i)
            elsif pre_tag_line?(line)
              close_open_lists
              i = process_pre_tag_block(lines, i)
            elsif blank_line?(line)
              close_open_lists
            else
              close_open_lists
              process_inline_content(line)
            end

            i += 1
          end
        end

        # Check if a line is a heading (starts and ends with = signs).
        #
        # @param line [String]
        # @return [Boolean]
        def heading_line?(line)
          line.match?(/\A={1,6}[^=].*[^=]={1,6}\s*\z/) || line.match?(/\A={1,6}[^=]+=*\s*\z/)
        end

        # Check if a line is a horizontal rule (4+ dashes).
        #
        # @param line [String]
        # @return [Boolean]
        def horizontal_rule_line?(line)
          line.match?(/\A-{4,}\s*\z/)
        end

        # Check if a line is a list item (starts with * or #).
        #
        # @param line [String]
        # @return [Boolean]
        def list_line?(line)
          line.match?(/\A[*#]/)
        end

        # Check if a line starts with a space (preformatted text).
        #
        # @param line [String]
        # @return [Boolean]
        def preformatted_line?(line)
          line.start_with?(" ")
        end

        # Check if a line starts a <pre> block.
        #
        # @param line [String]
        # @return [Boolean]
        def pre_tag_line?(line)
          line.match?(/\A\s*<pre\b/i)
        end

        # Check if a line is blank.
        #
        # @param line [String]
        # @return [Boolean]
        def blank_line?(line)
          line.strip.empty?
        end

        # Check if a line starts a table ({|).
        #
        # @param line [String]
        # @return [Boolean]
        def table_start_line?(line)
          line.match?(/\A\s*\{\|/)
        end

        # Process a table block from {| to |}.
        # Consumes lines until the closing |} is found.
        #
        # @param lines [Array<String>]
        # @param start_index [Integer]
        # @return [Integer] the last index consumed
        def process_table(lines, start_index)
          table = AST::Table.new
          current_row = nil
          i = start_index + 1 # Skip the {| line

          while i < lines.length
            stripped = lines[i].strip

            if stripped.start_with?("|}")
              break
            elsif stripped.start_with?("|-")
              # Row separator - next cells will go in a new row
              current_row = nil
            elsif stripped.start_with?("!")
              # Header cells
              current_row = ensure_table_row(table, current_row)
              parse_table_cells(stripped[1..], header: true, row: current_row)
            elsif stripped.start_with?("|")
              # Data cells
              current_row = ensure_table_row(table, current_row)
              parse_table_cells(stripped[1..], header: false, row: current_row)
            end

            i += 1
          end

          @document << table
          i
        end

        # Ensure a row exists for the table, creating one if needed.
        #
        # @param table [AST::Table]
        # @param current_row [AST::TableRow, nil]
        # @return [AST::TableRow]
        def ensure_table_row(table, current_row)
          return current_row if current_row

          row = AST::TableRow.new
          table << row
          row
        end

        # Parse cell content from a line and add cells to the row.
        # Cells are separated by !! (headers) or || (data cells).
        # Separators inside [[...]] internal links are preserved so that
        # pipes like [[Target|Display]] survive cell splitting.
        #
        # @param content [String] the line content after the leading ! or |
        # @param header [Boolean] whether these are header cells
        # @param row [AST::TableRow]
        def parse_table_cells(content, header:, row:)
          separator = header ? "!!" : "||"
          cells = split_outside_brackets(content, separator)

          cells.each do |raw_cell|
            # A single | in a cell separates attributes from content
            parts = split_outside_brackets(raw_cell, "|", limit: 2)
            cell_text = parts.last

            cell = AST::TableCell.new(header:)
            @inline_parser.parse(cell_text.strip, parent: cell)
            row << cell
          end
        end

        # Split content on separator, ignoring occurrences inside [[...]] pairs.
        # With limit: n, stops after n-1 splits (matching String#split semantics).
        #
        # @param content [String]
        # @param separator [String]
        # @param limit [Integer, nil]
        # @return [Array<String>]
        def split_outside_brackets(content, separator, limit: nil)
          parts = []
          buffer = +""
          depth = 0
          i = 0
          sep_len = separator.length

          while i < content.length
            if content[i, 2] == "[["
              depth += 1
              buffer << "[["
              i += 2
            elsif content[i, 2] == "]]" && depth.positive?
              depth -= 1
              buffer << "]]"
              i += 2
            elsif depth.zero? && content[i, sep_len] == separator &&
                  (limit.nil? || parts.length < limit - 1)
              parts << buffer
              buffer = +""
              i += sep_len
            else
              buffer << content[i]
              i += 1
            end
          end

          parts << buffer
          parts
        end

        # Process a heading line and add it to the document.
        #
        # @param line [String]
        def process_heading(line)
          stripped = line.strip
          # Count leading = signs for level
          level = 0
          level += 1 while level < stripped.length && stripped[level] == "="
          level = [level, 6].min

          # Remove leading/trailing = signs and whitespace
          content = stripped[level..].sub(/\s*={1,6}\s*\z/, "").strip

          heading = AST::Heading.new(level:)
          @inline_parser.parse(content, parent: heading)
          @document << heading
        end

        # Process a list item line, managing list nesting.
        #
        # @param line [String]
        def process_list_item(line)
          # Count prefix characters to determine depth and type
          prefix = +""
          i = 0
          while i < line.length && (line[i] == "*" || line[i] == "#")
            prefix << line[i]
            i += 1
          end

          content = line[i..].strip
          desired_depth = prefix.length

          # Adjust list stack to match desired depth
          reconcile_list_stack(prefix, desired_depth)

          # Create list item and add content
          item = AST::ListItem.new
          @inline_parser.parse(content, parent: item)
          @list_stack.last[:list] << item
        end

        # Reconcile the list stack with the desired prefix.
        # Opens new lists or closes existing ones as needed.
        #
        # @param prefix [String] the list prefix characters (e.g., "**#")
        # @param desired_depth [Integer]
        def reconcile_list_stack(prefix, desired_depth)
          # Close lists that no longer match
          @list_stack.pop while @list_stack.length > desired_depth

          # Check if existing stack entries match the type at each level
          prefix.chars.each_with_index do |char, idx|
            ordered = char == "#"
            if idx < @list_stack.length
              # If type changed at this level, close from here and reopen
              if @list_stack[idx][:ordered] != ordered
                @list_stack.pop while @list_stack.length > idx
                open_new_list(ordered, idx)
              end
            else
              open_new_list(ordered, idx)
            end
          end
        end

        # Open a new list at the given depth.
        #
        # @param ordered [Boolean]
        # @param depth [Integer]
        def open_new_list(ordered, depth)
          list = AST::List.new(ordered:)

          if depth.zero?
            @document << list
          else
            # Nest inside the last item of the parent list
            parent_list = @list_stack.last[:list]
            parent_list << AST::ListItem.new if parent_list.children.empty?
            parent_list.children.last << list
          end

          @list_stack << { list:, ordered: }
        end

        # Close all open lists.
        def close_open_lists
          @list_stack.clear
        end

        # Process consecutive lines starting with a space as a preformatted block.
        #
        # @param lines [Array<String>]
        # @param start_index [Integer]
        # @return [Integer] the last index consumed (will be incremented by caller)
        def process_preformatted_block(lines, start_index)
          content_lines = []
          i = start_index

          while i < lines.length && lines[i].start_with?(" ")
            content_lines << lines[i][1..] # Remove leading space
            i += 1
          end

          code = AST::Code.new
          code << AST::Text.new(content_lines.join("\n"))
          @document << code

          i - 1 # Return last consumed index
        end

        # Process a <pre>...</pre> block that may span multiple lines.
        #
        # @param lines [Array<String>]
        # @param start_index [Integer]
        # @return [Integer] the last index consumed
        def process_pre_tag_block(lines, start_index)
          combined = +""
          i = start_index

          while i < lines.length
            combined << lines[i]
            break if lines[i].match?(%r{</pre\s*>}i)
            combined << "\n"
            i += 1
          end

          # Extract content between <pre> and </pre>
          content = combined.sub(/\A\s*<pre\b[^>]*>/i, "").sub(%r{</pre\s*>\s*\z}i, "")

          code = AST::Code.new
          code << AST::Text.new(content)
          @document << code

          i
        end

        # Process a line as inline content wrapped in a paragraph.
        #
        # @param line [String]
        def process_inline_content(line)
          paragraph = AST::Paragraph.new
          @inline_parser.parse(line, parent: paragraph)
          @document << paragraph
        end
      end
    end
  end
end
