# frozen_string_literal: true

module Markbridge
  module Parsers
    module MediaWiki
      # Parses inline MediaWiki markup within a line of text.
      # Handles bold ('''), italic (''), links ([[...]]), external links ([...]),
      # and HTML inline tags (<code>, <nowiki>, <s>, <del>, <u>, <ins>, <sup>, <sub>, <br>).
      class InlineParser
        include Markbridge::ProgressGuard

        # Parse inline markup and append resulting AST nodes to the parent element.
        #
        # @param text [String] the text to parse for inline markup
        # @param parent [AST::Element] the element to append children to
        def parse(text, parent:)
          @input = text
          @pos = 0
          @length = text.length
          @parent = parent
          @text_buffer = +""
          reset_progress_guard

          while @pos < @length
            progressed!(@pos)
            char = @input[@pos]

            case char
            when "'"
              consecutive_apostrophes_at(@pos) >= 2 ? parse_bold_italic : append_literal(char)
            when "["
              flush_text
              @input[@pos + 1] == "[" ? parse_internal_link : parse_external_link
            when "<"
              flush_text
              parse_html_tag
            else
              append_literal(char)
            end
          end

          flush_text
        end

        private

        def append_literal(char)
          @text_buffer << char
          @pos += 1
        end

        # Count consecutive apostrophes and dispatch to bold/italic parsing.
        # Precondition: caller has verified @input[@pos..@pos+1] is "''".
        def parse_bold_italic
          start = @pos
          count = [consecutive_apostrophes_at(@pos), 5].min
          flush_text
          @pos += count
          parse_apostrophe_formatting(count, start)
        end

        # Parse apostrophe-delimited formatting (bold, italic, or bold+italic).
        #
        # @param apostrophe_count [Integer] number of apostrophes (2, 3, or 5)
        # @param start [Integer] position before the opening apostrophes
        def parse_apostrophe_formatting(apostrophe_count, start)
          content = collect_until_apostrophes(apostrophe_count)

          unless content
            @text_buffer << ("'" * apostrophe_count)
            @pos = start + apostrophe_count
            return
          end

          element = build_formatting_element(apostrophe_count)
          parse_inner_content(content, parent: innermost_element(element))
          @parent << element
        end

        # Build the AST element(s) for the given apostrophe count.
        def build_formatting_element(apostrophe_count)
          case apostrophe_count
          when 5
            AST::Bold.new << AST::Italic.new
          when 3
            AST::Bold.new
          when 2
            AST::Italic.new
          end
        end

        # Return the innermost element to receive parsed content.
        def innermost_element(element)
          element.children.empty? ? element : element.children.last
        end

        # Parse inner content and append to a parent element.
        def parse_inner_content(content, parent:)
          InlineParser.new.parse(content, parent:)
        end

        # Collect text until we find n consecutive apostrophes.
        # Returns the collected content string or nil if not found.
        #
        # @param count [Integer] number of consecutive apostrophes to match
        # @return [String, nil]
        def collect_until_apostrophes(count)
          start = @pos
          guard_last_pos = -1
          while @pos < @length
            pos = @pos
            raise ParserStuckError.new(parser: self.class, pos:) if pos <= guard_last_pos

            guard_last_pos = pos
            if consecutive_apostrophes_at(pos) >= count
              content = @input[start...pos]
              @pos = pos + count
              return content
            end
            @pos = pos + 1
          end
        end

        # Count consecutive apostrophes starting at position.
        #
        # @param pos [Integer]
        # @return [Integer]
        def consecutive_apostrophes_at(pos)
          @input[pos..].each_char.take_while { |c| c == "'" }.length
        end

        # Parse [[internal link]] or [[target|display text]].
        def parse_internal_link
          @pos += 2 # skip [[
          start = @pos

          # Find closing ]]
          close_pos = @input.index("]]", @pos)
          unless close_pos
            @text_buffer << "[["
            return
          end

          content = @input[start...close_pos]
          @pos = close_pos + 2

          target, display = content.split("|", 2)
          target = target.strip
          display = (display || target).strip

          url = AST::Url.new(href: target)
          url << AST::Text.new(display)
          @parent << url
        end

        # Parse [url display text] external link.
        def parse_external_link
          @pos += 1 # skip [
          start = @pos

          # Find closing ]
          close_pos = @input.index("]", @pos)
          unless close_pos
            @text_buffer << "["
            return
          end

          content = @input[start...close_pos]
          @pos = close_pos + 1

          # Split on first space: URL followed by optional display text
          parts = content.split(" ", 2)
          href = parts[0]
          display = parts[1] || href

          url = AST::Url.new(href:)
          url << AST::Text.new(display)
          @parent << url
        end

        # Parse an HTML tag (<code>, <nowiki>, <pre>, <br>, <s>, <del>, <u>, <ins>, <sup>, <sub>).
        def parse_html_tag
          tag_match = @input[@pos..].match(%r{\A<(/?)([a-z]+)(?: [^>]*)?\s*(/?)>}i)
          unless tag_match
            @text_buffer << "<"
            @pos += 1
            return
          end

          full_match = tag_match[0]
          closing = !tag_match[1].empty?
          self_closing = !tag_match[3].empty?
          tag_name = tag_match[2].downcase

          # Closing/self-closing tags and unknown tags are treated as literal text
          if closing || self_closing || !known_html_tag?(tag_name)
            advance_as_text(full_match)
            return
          end

          case tag_name
          when "nowiki"
            handle_nowiki_tag(full_match)
          when "code", "pre"
            handle_paired_raw_tag(tag_name, full_match, AST::Code)
          when "br"
            @pos += full_match.length
            @parent << AST::LineBreak.new
          when "s", "del"
            handle_paired_tag(tag_name, full_match, AST::Strikethrough)
          when "u", "ins"
            handle_paired_tag(tag_name, full_match, AST::Underline)
          when "sup"
            handle_paired_tag(tag_name, full_match, AST::Superscript)
          when "sub"
            handle_paired_tag(tag_name, full_match, AST::Subscript)
          end
        end

        KNOWN_HTML_TAGS = %w[nowiki code pre br s del u ins sup sub].freeze

        def known_html_tag?(tag_name)
          KNOWN_HTML_TAGS.include?(tag_name)
        end

        # Advance position and buffer the match as literal text.
        def advance_as_text(full_match)
          @text_buffer << full_match
          @pos += full_match.length
        end

        # Handle <nowiki>...</nowiki> - preserves content as literal text.
        def handle_nowiki_tag(full_match)
          @pos += full_match.length
          close_pos = @input.index("</nowiki>", @pos)

          if close_pos
            @text_buffer << @input[@pos...close_pos]
            @pos = close_pos + "</nowiki>".length
          else
            @text_buffer << full_match
          end
        end

        # Handle paired raw tags like <code>...</code> and <pre>...</pre>.
        # Content inside is not parsed for wiki markup.
        def handle_paired_raw_tag(tag_name, full_match, element_class)
          @pos += full_match.length
          close_tag = "</#{tag_name}>"
          close_pos = @input.index(close_tag, @pos)

          if close_pos
            element = element_class.new
            element << AST::Text.new(@input[@pos...close_pos])
            @parent << element
            @pos = close_pos + close_tag.length
          else
            @text_buffer << full_match
          end
        end

        # Handle paired formatting tags like <s>, <u>, <sup>, <sub>.
        # Content inside IS parsed for wiki markup.
        def handle_paired_tag(tag_name, full_match, element_class)
          @pos += full_match.length
          close_tag = "</#{tag_name}>"
          close_pos = @input.index(close_tag, @pos)

          if close_pos
            element = element_class.new
            parse_inner_content(@input[@pos...close_pos], parent: element)
            @parent << element
            @pos = close_pos + close_tag.length
          else
            @text_buffer << full_match
          end
        end

        # Flush accumulated text buffer to the parent as a Text node.
        def flush_text
          return if @text_buffer.empty?

          @parent << AST::Text.new(@text_buffer)
          @text_buffer = +""
        end
      end
    end
  end
end
