# frozen_string_literal: true

module Markbridge
  module Parsers
    module MediaWiki
      # Parses inline MediaWiki markup within a line of text.
      # Handles bold ('''), italic (''), links ([[...]]), external links ([...]),
      # and HTML inline tags via an InlineTagRegistry.
      #
      # @example With custom registry
      #   registry = InlineTagRegistry.build_from_default do |r|
      #     r.register("mark", :formatting, AST::Bold)
      #   end
      #   parser = InlineParser.new(inline_tag_registry: registry)
      class InlineParser
        MAX_INLINE_DEPTH = 20

        def initialize(inline_tag_registry: nil, depth: 0)
          @registry = inline_tag_registry || InlineTagRegistry.default
          @depth = depth
          @input = nil
          @pos = 0
          @length = 0
          @parent = nil
          @text_buffer = +""
        end

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
            char = @input[@pos]
            next_char = @pos + 1 < @length ? @input[@pos + 1] : nil

            case char
            when "'"
              if next_char == "'"
                parse_bold_italic
              else
                @text_buffer << char
                @pos += 1
              end
            when "["
              flush_text
              if next_char == "["
                parse_internal_link
              else
                parse_external_link
              end
            when "<"
              flush_text
              parse_html_tag
            else
              @text_buffer << char
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
          # Clamp: 5 = bold+italic, 3 = bold, 2 = italic
          count = [count, 5].min

          if count < 2
            @text_buffer << @input[@pos]
            @pos += 1
          else
            flush_text
            @pos += count
            parse_apostrophe_formatting(count, start)
          end
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
            bold = AST::Bold.new
            bold << AST::Italic.new
            bold
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
        # Respects MAX_INLINE_DEPTH to prevent stack overflow from deeply nested markup.
        def parse_inner_content(content, parent:)
          if @depth + 1 >= MAX_INLINE_DEPTH
            parent << AST::Text.new(content)
            return
          end

          InlineParser.new(inline_tag_registry: @registry, depth: @depth + 1).parse(content, parent:)
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

          full_match = tag_match[0]
          closing = !tag_match[1].empty?
          self_closing = !tag_match[3].empty?
          tag_name = tag_match[2].downcase

          # Closing/self-closing tags and unknown tags are treated as literal text
          entry = @registry[tag_name]
          if closing || self_closing || !entry
            advance_as_text(full_match)
            return
          end

          dispatch_html_tag(entry, tag_name, full_match)
        end

        # Dispatch an HTML-like tag based on its registry entry type.
        def dispatch_html_tag(entry, tag_name, full_match)
          case entry.type
          when :raw
            if entry.element_class.nil?
              handle_nowiki_tag(full_match)
            else
              handle_paired_raw_tag(tag_name, full_match, entry.element_class)
            end
          when :formatting
            handle_paired_tag(tag_name, full_match, entry.element_class)
          when :self_closing
            @pos += full_match.length
            @parent << entry.element_class.new
          end
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
