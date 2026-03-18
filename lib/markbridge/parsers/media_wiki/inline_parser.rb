# frozen_string_literal: true

module Markbridge
  module Parsers
    module MediaWiki
      # Parses inline MediaWiki markup within a line of text.
      # Handles bold ('''), italic (''), links ([[...]]), external links ([...]),
      # and HTML inline tags (<code>, <nowiki>, <s>, <del>, <u>, <ins>, <sup>, <sub>, <br>).
      class InlineParser
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

          while @pos < @length
            if @input[@pos] == "'" && @pos + 1 < @length && @input[@pos + 1] == "'"
              parse_bold_italic
            elsif @input[@pos] == "[" && @pos + 1 < @length && @input[@pos + 1] == "["
              flush_text
              parse_internal_link
            elsif @input[@pos] == "[" && !(@pos + 1 < @length && @input[@pos + 1] == "[")
              flush_text
              parse_external_link
            elsif @input[@pos] == "<"
              flush_text
              parse_html_tag
            else
              @text_buffer << @input[@pos]
              @pos += 1
            end
          end

          flush_text
        end

        private

        # Count consecutive apostrophes and dispatch to bold/italic parsing.
        def parse_bold_italic
          start = @pos
          count = 0
          count += 1 while @pos + count < @length && @input[@pos + count] == "'"
          count = 5 if count > 5

          if count >= 5
            flush_text
            @pos += 5
            parse_bold_italic_combo(start)
          elsif count >= 3
            flush_text
            @pos += 3
            parse_bold_content(start)
          elsif count >= 2
            flush_text
            @pos += 2
            parse_italic_content(start)
          else
            @text_buffer << @input[@pos]
            @pos += 1
          end
        end

        # Parse '''''bold italic''''' content.
        def parse_bold_italic_combo(start)
          bold = AST::Bold.new
          italic = AST::Italic.new
          content = collect_until_apostrophes(5)

          if content
            inner_parser = InlineParser.new
            inner_parser.parse(content, parent: italic)
            bold << italic
            @parent << bold
          else
            # No closing found - treat as literal text
            @text_buffer << "'''''"
            @pos = start + 5
          end
        end

        # Parse '''bold''' content.
        def parse_bold_content(start)
          bold = AST::Bold.new
          content = collect_until_apostrophes(3)

          if content
            inner_parser = InlineParser.new
            inner_parser.parse(content, parent: bold)
            @parent << bold
          else
            @text_buffer << "'''"
            @pos = start + 3
          end
        end

        # Parse ''italic'' content.
        def parse_italic_content(start)
          italic = AST::Italic.new
          content = collect_until_apostrophes(2)

          if content
            inner_parser = InlineParser.new
            inner_parser.parse(content, parent: italic)
            @parent << italic
          else
            @text_buffer << "''"
            @pos = start + 2
          end
        end

        # Collect text until we find n consecutive apostrophes.
        # Returns the collected content string or nil if not found.
        #
        # @param count [Integer] number of consecutive apostrophes to match
        # @return [String, nil]
        def collect_until_apostrophes(count)
          start = @pos
          while @pos < @length
            if @input[@pos] == "'" && consecutive_apostrophes_at(@pos) >= count
              content = @input[start...@pos]
              @pos += count
              return content
            end
            @pos += 1
          end
          nil
        end

        # Count consecutive apostrophes starting at position.
        #
        # @param pos [Integer]
        # @return [Integer]
        def consecutive_apostrophes_at(pos)
          count = 0
          count += 1 while pos + count < @length && @input[pos + count] == "'"
          count
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

          closing = !tag_match[1].empty?
          tag_name = tag_match[2].downcase
          self_closing = !tag_match[3].empty?
          full_match = tag_match[0]

          case tag_name
          when "nowiki"
            handle_nowiki_tag(closing, full_match)
          when "code"
            handle_paired_raw_tag(tag_name, closing, full_match, AST::Code)
          when "pre"
            handle_paired_raw_tag(tag_name, closing, full_match, AST::Code)
          when "br"
            @pos += full_match.length
            @parent << AST::LineBreak.new
          when "s", "del"
            handle_paired_tag(tag_name, closing, self_closing, full_match, AST::Strikethrough)
          when "u", "ins"
            handle_paired_tag(tag_name, closing, self_closing, full_match, AST::Underline)
          when "sup"
            handle_paired_tag(tag_name, closing, self_closing, full_match, AST::Superscript)
          when "sub"
            handle_paired_tag(tag_name, closing, self_closing, full_match, AST::Subscript)
          else
            # Unknown HTML tag - treat as text
            @text_buffer << full_match
            @pos += full_match.length
          end
        end

        # Handle <nowiki>...</nowiki> - preserves content as literal text.
        def handle_nowiki_tag(closing, full_match)
          if closing
            @text_buffer << full_match
            @pos += full_match.length
            return
          end

          @pos += full_match.length
          close_tag = "</nowiki>"
          close_pos = @input.index(close_tag, @pos)

          if close_pos
            raw_content = @input[@pos...close_pos]
            @text_buffer << raw_content
            @pos = close_pos + close_tag.length
          else
            # No closing tag found - treat opening tag as text
            @text_buffer << full_match
          end
        end

        # Handle paired raw tags like <code>...</code> and <pre>...</pre>.
        # Content inside is not parsed for wiki markup.
        def handle_paired_raw_tag(tag_name, closing, full_match, element_class)
          if closing
            @text_buffer << full_match
            @pos += full_match.length
            return
          end

          @pos += full_match.length
          close_tag = "</#{tag_name}>"
          close_pos = @input.index(close_tag, @pos)

          if close_pos
            raw_content = @input[@pos...close_pos]
            element = element_class.new
            element << AST::Text.new(raw_content)
            @parent << element
            @pos = close_pos + close_tag.length
          else
            @text_buffer << full_match
          end
        end

        # Handle paired formatting tags like <s>, <u>, <sup>, <sub>.
        # Content inside IS parsed for wiki markup.
        def handle_paired_tag(tag_name, closing, self_closing, full_match, element_class)
          if closing || self_closing
            @text_buffer << full_match
            @pos += full_match.length
            return
          end

          @pos += full_match.length
          # Find matching close tag, accounting for the alias tags
          close_tags = close_tags_for(tag_name)
          close_pos = nil
          close_tag_length = 0

          close_tags.each do |ct|
            pos = @input.index(ct, @pos)
            if pos && (close_pos.nil? || pos < close_pos)
              close_pos = pos
              close_tag_length = ct.length
            end
          end

          if close_pos
            inner_content = @input[@pos...close_pos]
            element = element_class.new
            inner_parser = InlineParser.new
            inner_parser.parse(inner_content, parent: element)
            @parent << element
            @pos = close_pos + close_tag_length
          else
            @text_buffer << full_match
          end
        end

        # Return the possible closing tags for a given tag name.
        #
        # @param tag_name [String]
        # @return [Array<String>]
        def close_tags_for(tag_name)
          ["</#{tag_name}>"]
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
