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
      # - HTML tags: <nowiki>, <code>, <pre>, <br>, <s>, <del>, <u>, <ins>, <sup>, <sub>
      #
      # @example Basic usage
      #   parser = Markbridge::Parsers::MediaWiki::Parser.new
      #   ast = parser.parse("'''bold''' and ''italic''")
      class Parser
        # Parse MediaWiki wikitext into an AST Document.
        #
        # @param input [String] MediaWiki source
        # @return [AST::Document]
        def parse(input)
          normalized = normalize_line_endings(input)
          lines = normalized.split("\n", -1)

          @document = AST::Document.new
          @inline_parser = InlineParser.new
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
