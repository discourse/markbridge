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
        include Markbridge::ProgressGuard

        # Parse MediaWiki wikitext into an AST Document.
        #
        # @param input [String] MediaWiki source
        # @return [AST::Document]
        def parse(input)
          normalized = normalize_line_endings(input)
          lines = normalized.split("\n")

          @document = AST::Document.new
          @inline_parser = InlineParser.new
          @list_stack = []
          reset_progress_guard

          process_lines(lines)
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
            progressed!(i)
            line = lines.fetch(i)

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

        HEADING_LINE = /\A={1,6}(?:[^=].*[^=]={1,6}|[^=]+=*)\s*\z/
        private_constant :HEADING_LINE

        # Check if a line is a heading (starts and ends with = signs).
        #
        # @param line [String]
        # @return [Boolean]
        def heading_line?(line)
          line.match?(HEADING_LINE)
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
          !line.match?(/\S/)
        end

        HEADING_LEVEL_PREFIX = /\A={1,6}/
        HEADING_LEVEL_SUFFIX = /\s*={1,6}\s*\z/
        private_constant :HEADING_LEVEL_PREFIX, :HEADING_LEVEL_SUFFIX

        # Process a heading line and add it to the document.
        #
        # @param line [String]
        def process_heading(line)
          leading = line[HEADING_LEVEL_PREFIX]
          content = line[leading.length..].sub(HEADING_LEVEL_SUFFIX, "").strip

          heading = AST::Heading.new(level: leading.length)
          @inline_parser.parse(content, parent: heading)
          @document << heading
        end

        # Process a list item line, managing list nesting.
        #
        # @param line [String]
        def process_list_item(line)
          prefix = line[/\A[*#]+/]
          content = line[prefix.length..].strip

          reconcile_list_stack(prefix)

          item = AST::ListItem.new
          @inline_parser.parse(content, parent: item)
          @list_stack.last.fetch(:list) << item
        end

        # Reconcile the list stack with the desired prefix.
        # Opens new lists or closes existing ones as needed.
        #
        # @param prefix [String] the list prefix characters (e.g., "**#")
        def reconcile_list_stack(prefix)
          keep = matching_prefix_depth(prefix)
          while @list_stack.length > keep
            len_before = @list_stack.length
            @list_stack.pop
            len_after = @list_stack.length
            if len_after >= len_before
              raise ParserStuckError.new(parser: self.class, pos: len_after)
            end
          end
          prefix[keep..].each_char { |char| open_new_list(char == "#", @list_stack.length) }
        end

        def matching_prefix_depth(prefix)
          @list_stack.take_while.with_index { |entry, i| entry.fetch(:char) == prefix[i] }.length
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
            parent_list = @list_stack.last.fetch(:list)
            parent_list << AST::ListItem.new if parent_list.children.empty?
            parent_list.children.last << list
          end

          @list_stack << { list:, char: ordered ? "#" : "*" }
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
          consumed = lines[start_index..].take_while { |line| line.start_with?(" ") }
          content = consumed.map { |line| line[1..] }.join("\n")

          code = AST::Code.new
          code << AST::Text.new(content)
          @document << code

          start_index + consumed.length - 1
        end

        PRE_TAG_OPEN = /\A\s*<pre\b[^>]*>/i
        PRE_TAG_CLOSE = %r{</pre\s*>}i
        PRE_TAG_CLOSE_TRAILING = %r{</pre\s*>\s*\z}i
        private_constant :PRE_TAG_OPEN, :PRE_TAG_CLOSE, :PRE_TAG_CLOSE_TRAILING

        # Process a <pre>...</pre> block that may span multiple lines.
        #
        # @param lines [Array<String>]
        # @param start_index [Integer]
        # @return [Integer] the last index consumed
        def process_pre_tag_block(lines, start_index)
          consumed = lines[start_index..].take_while { |line| !line.match?(PRE_TAG_CLOSE) }
          terminated = consumed.length < lines.length - start_index
          consumed << lines.fetch(start_index + consumed.length) if terminated

          combined = consumed.join("\n")
          content = combined.sub(PRE_TAG_OPEN, "").sub(PRE_TAG_CLOSE_TRAILING, "")

          code = AST::Code.new
          code << AST::Text.new(content)
          @document << code

          start_index + consumed.length - 1
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
