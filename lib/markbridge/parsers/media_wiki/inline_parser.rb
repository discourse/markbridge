# frozen_string_literal: true

module Markbridge
  module Parsers
    module MediaWiki
      # Parses inline MediaWiki markup within a line of text.
      # Handles bold ('''), italic (''), links ([[...]]), external links ([...]),
      # and HTML inline tags via an InlineTagRegistry.
      #
      # The parser works in *byte* offsets (byteindex/byteslice/getbyte):
      # character indices are O(pos) on multibyte input in CRuby, and
      # per-character probes allocate a String each. The main loop jumps
      # between interesting bytes with a single regex search and copies
      # the skipped span in one slice. Invariant: +@pos+ always sits on a
      # character boundary — jumps land on ASCII matches and advances
      # step over ASCII bytes or whole matches.
      #
      # @example With custom registry
      #   registry = InlineTagRegistry.build_from_default do |r|
      #     r.register("mark", :formatting, AST::Bold)
      #   end
      #   parser = InlineParser.new(handlers: registry)
      class InlineParser
        MAX_INLINE_DEPTH = 20

        # Bytes the main loop reacts to: apostrophes ('), link openers ([)
        # and HTML tag openers (<). ASCII-only, so a byteindex match always
        # lands on a character boundary.
        INTERESTING = /['\[<]/
        APOSTROPHE = 39 # '
        BRACKET_OPEN = 91 # [
        private_constant :INTERESTING, :APOSTROPHE, :BRACKET_OPEN

        # Matches an HTML-like tag at the search position (\G with
        # byteindex anchors at the offset).
        HTML_TAG_AT_CURSOR = %r{\G<(/?)([a-z]+)(?: [^>]*)?\s*(/?)>}i
        private_constant :HTML_TAG_AT_CURSOR

        # @return [Hash{String => Integer}] tag-name → occurrence count for
        #   HTML-like inline tags whose names are not registered. Shared
        #   with nested InlineParser instances so depth-recursive parses
        #   contribute to the same tally.
        attr_reader :unknown_tags

        def initialize(handlers: nil, depth: 0, unknown_tags: nil)
          @registry = handlers || InlineTagRegistry.shared_default
          @depth = depth
          @unknown_tags = unknown_tags || Hash.new(0)
        end

        # Parse inline markup and append resulting AST nodes to the parent element.
        #
        # @param text [String] the text to parse for inline markup
        # @param parent [AST::Element] the element to append children to
        def parse(text, parent:)
          @input = text
          @pos = 0
          @length = text.bytesize
          @parent = parent
          @text_buffer = +""

          while (span_end = @input.byteindex(INTERESTING, @pos))
            # Unconditional on purpose: when the interesting byte sits at
            # @pos the slice is empty and both lines are no-ops.
            @text_buffer << @input.byteslice(@pos, span_end - @pos)
            @pos = span_end

            dispatch_interesting_byte
          end

          # Trailing text after the last interesting byte; appending the
          # empty slice at end-of-input is a no-op.
          @text_buffer << @input.byteslice(@pos, @length - @pos)
          flush_text
        end

        private

        # Precondition: the byte at +@pos+ matched INTERESTING.
        def dispatch_interesting_byte
          case @input.getbyte(@pos)
          when APOSTROPHE
            if consecutive_apostrophes_at(@pos) >= 2
              parse_bold_italic
            else
              @text_buffer << "'"
              @pos += 1
            end
          when BRACKET_OPEN
            flush_text
            @input.getbyte(@pos + 1) == BRACKET_OPEN ? parse_internal_link : parse_external_link
          else # "<" — the only remaining INTERESTING byte
            flush_text
            parse_html_tag
          end
        end

        # Precondition: caller has verified at least two apostrophes at @pos.
        def parse_bold_italic
          count = [consecutive_apostrophes_at(@pos), 5].min
          flush_text
          @pos += count
          parse_apostrophe_formatting(count)
        end

        # Parse apostrophe-delimited formatting (bold, italic, or bold+italic).
        # Entered with @pos just past the opening apostrophes.
        #
        # @param apostrophe_count [Integer] number of apostrophes (2, 3, or 5)
        def parse_apostrophe_formatting(apostrophe_count)
          content = collect_until_apostrophes(apostrophe_count)

          unless content
            # @pos already sits just past the opening apostrophes
            # (start + apostrophe_count): the caller advanced it, and
            # collect_until_apostrophes leaves it untouched on failure.
            @text_buffer << ("'" * apostrophe_count)
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
        # Respects MAX_INLINE_DEPTH to prevent stack overflow from deeply nested markup.
        def parse_inner_content(content, parent:)
          if @depth + 1 >= MAX_INLINE_DEPTH
            parent << AST::Text.new(content)
            return
          end

          InlineParser.new(
            handlers: @registry,
            depth: @depth + 1,
            unknown_tags: @unknown_tags,
          ).parse(content, parent:)
        end

        # Collect text until we find n consecutive apostrophes, hopping
        # from apostrophe run to apostrophe run instead of scanning per
        # position. Returns the collected content string, or nil (the
        # exhausted while loop) if no closing run exists.
        #
        # Three apostrophes inside italic open bold, they do not end the
        # italic: the search goes on behind the end of that bold. Five
        # apostrophes there end the bold with three and the italic with
        # the two that are left.
        #
        # @param count [Integer] number of consecutive apostrophes to match
        # @return [String, nil]
        def collect_until_apostrophes(count)
          start = @pos
          probe = @pos
          while (index = @input.byteindex("'", probe))
            run = consecutive_apostrophes_at(index)
            if run >= count
              bold_end = (bold_end_after(index + BOLD) if count == ITALIC && run == BOLD)
              if bold_end
                probe = bold_end
                next
              end

              content = @input.byteslice(start, index - start)
              @pos = index + count
              return content
            end
            probe = index + run
          end
        end

        ITALIC = 2
        BOLD = 3
        private_constant :ITALIC, :BOLD

        # @param from [Integer] the position behind three apostrophes that
        #   open bold
        # @return [Integer, nil] the position behind the three apostrophes
        #   that close it, nil when nothing closes it
        def bold_end_after(from)
          while (index = @input.byteindex("'", from))
            run = consecutive_apostrophes_at(index)
            return index + BOLD if run >= BOLD

            from = index + run
          end
        end

        # Count consecutive apostrophes starting at position.
        # getbyte past end-of-input returns nil, which ends the run.
        #
        # @param pos [Integer]
        # @return [Integer]
        def consecutive_apostrophes_at(pos)
          count = 0
          count += 1 while @input.getbyte(pos + count) == APOSTROPHE
          count
        end

        # Parse [[internal link]] or [[target|display text]].
        def parse_internal_link
          @pos += 2 # skip [[
          start = @pos

          close_pos = link_close(@pos)
          unless close_pos
            @text_buffer << "[["
            return
          end

          content = @input.byteslice(start, close_pos - start)
          @pos = close_pos + 2

          # Nothing between the brackets is not a link, MediaWiki shows
          # the brackets.
          if content.empty?
            @text_buffer << "[[]]"
            return
          end

          target, display = content.split("|", 2)
          target = target.strip
          # A category puts the page into it and shows nothing in the text.
          return if target.match?(CATEGORY)
          return file_embed(target, display) if target.match?(FILE)

          display = (display || target).strip

          url = AST::Url.new(href: page_href(target))
          url << AST::Text.new(display)
          @parent << url
        end

        CATEGORY = /\Acategory:/i
        FILE = /\A(?:file|image):/i
        IMAGE_NAME = /\.(?:png|jpe?g|gif|svg|webp|bmp|tiff?)\z/i
        # `200px`, `200x100px` or `x100px`.
        FILE_SIZE = /\A(\d+)?(?:x(\d+))?px\z/i
        FILE_ALT = /\Aalt=/i
        # What says how MediaWiki shows the file, which Markdown has no
        # form for: the frame, the alignment and the named options.
        FILE_OPTION =
          /\A(?:thumb|thumbnail|frame|framed|frameless|border|left|right|center|none|baseline|sub|super|top|text-top|middle|bottom|text-bottom|upright|(?:upright|link|class|lang|page|thumb|thumbnail)=.*)\z/i
        # The parameters are apart by pipes, but not by the pipe of a link
        # in the caption.
        FILE_PARAMETER = /(?:\[\[[^\]]*\]\]|[^|])+/
        WIKI_MARKUP = /\[\[(?:[^\]|]*\|)?([^\]]*)\]\]|'{2,}/
        private_constant :CATEGORY,
                         :FILE,
                         :IMAGE_NAME,
                         :FILE_SIZE,
                         :FILE_ALT,
                         :FILE_OPTION,
                         :FILE_PARAMETER,
                         :WIKI_MARKUP

        # A link in a link in the caption of a file is as deep as wikitext
        # goes. The limit also keeps the search short for a row of `[[`
        # that nothing closes: without it every one of them would look
        # through all the others.
        MAX_LINK_NESTING = 3
        LINK_EDGE = /\[\[|\]\]/
        private_constant :MAX_LINK_NESTING, :LINK_EDGE

        # The `]]` that closes the link whose content starts at +from+. A
        # link inside, in the caption of a file for example, has its own.
        #
        # @return [Integer, nil] nil when nothing closes the link, or when
        #   more than MAX_LINK_NESTING links are open inside of it
        def link_close(from)
          depth = 0
          while (index = @input.byteindex(LINK_EDGE, from))
            if @input.getbyte(index) == BRACKET_OPEN
              return if depth == MAX_LINK_NESTING

              depth += 1
            elsif depth.zero?
              return index
            else
              depth -= 1
            end
            from = index + 2
          end
        end

        # `[[File:Name.jpg|thumb|200x100px|alt=...|Caption]]`. An image is
        # an image with the caption as its alternative text. Its address
        # is the page that MediaWiki answers with the file itself,
        # Special:FilePath. Any other file is a link to its page.
        #
        # @param target [String] the name with its namespace
        # @param parameters [String, nil] what follows the first pipe
        def file_embed(target, parameters)
          name = target.sub(FILE, "").lstrip
          alt = caption = width = height = nil
          parameters
            .to_s
            .scan(FILE_PARAMETER) do |parameter|
              parameter = parameter.strip
              if (size = FILE_SIZE.match(parameter))
                width = size[1]&.to_i
                height = size[2]&.to_i
              elsif parameter.match?(FILE_ALT)
                alt = parameter.sub(FILE_ALT, "")
              elsif !parameter.match?(FILE_OPTION)
                caption = parameter
              end
            end
          text = (alt || caption)&.gsub(WIKI_MARKUP, "\\1")

          if name.match?(IMAGE_NAME)
            src = page_href("Special:FilePath/#{name}")
            @parent << AST::Image.new(src:, alt: text, width:, height:)
          else
            @parent << (
              AST::Url.new(href: page_href("File:#{name}")) << AST::Text.new(text || name)
            )
          end
        end

        # The href of a wiki page, in the form MediaWiki's Parsoid writes
        # it: relative to the wiki, with underscores for the spaces of the
        # title, `./Main_Page`. The renderer reads it as a path, so the
        # link stays a link, and a consumer finds every page link by the
        # `./` and can put the address of the wiki in front. A link to a
        # section of the same page, `#History`, and an empty target stay
        # as they are. A `?` in the title is written as `%3F`, like
        # Parsoid does: left as it is, it would start the query of the
        # URL and the link would go to the page without it.
        def page_href(target)
          return target if target.empty? || target.start_with?("#")

          title, hash, section = target.delete_prefix(":").tr(" ", "_").partition("#")
          "./#{title.gsub("?", "%3F")}#{hash}#{section}"
        end

        # Parse [url display text] external link.
        def parse_external_link
          @pos += 1 # skip [
          start = @pos

          close_pos = @input.byteindex("]", @pos)
          unless close_pos
            @text_buffer << "["
            return
          end

          content = @input.byteslice(start, close_pos - start)
          @pos = close_pos + 1

          # Split on first space: URL followed by optional display text
          parts = content.split(" ", 2)
          href = parts[0]
          display = parts[1] || href

          url = AST::Url.new(href:)
          url << AST::Text.new(display)
          @parent << url
        end

        def parse_html_tag
          unless @input.byteindex(HTML_TAG_AT_CURSOR, @pos)
            @text_buffer << "<"
            @pos += 1
            return
          end

          tag_match = Regexp.last_match
          full_match = tag_match[0]
          closing = !tag_match[1].empty?
          self_closing = !tag_match[3].empty?
          tag_name = tag_match[2].downcase

          # Closing/self-closing tags and unknown tags are treated as literal text.
          # Track *unknown* opening tags so callers can surface them via
          # Parse/Conversion#unknown_tags. We deliberately don't track
          # closing/self-closing forms — they often pair up with the
          # opening tag that's already counted.
          entry = @registry[tag_name]
          if closing || self_closing || !entry
            @unknown_tags[tag_name] += 1 if !entry && !closing && !self_closing
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
            @pos += full_match.bytesize
            @parent << entry.element_class.new
          end
        end

        # Advance position and buffer the match as literal text.
        def advance_as_text(full_match)
          @text_buffer << full_match
          @pos += full_match.bytesize
        end

        # Handle <nowiki>...</nowiki> - preserves content as literal text.
        def handle_nowiki_tag(full_match)
          @pos += full_match.bytesize
          close_pos, close_size = find_close("nowiki")

          if close_pos
            @text_buffer << @input.byteslice(@pos, close_pos - @pos)
            @pos = close_pos + close_size
          else
            @text_buffer << full_match
          end
        end

        # Handle paired raw tags like <code>...</code> and <pre>...</pre>.
        # Content inside is not parsed for wiki markup.
        def handle_paired_raw_tag(tag_name, full_match, element_class)
          @pos += full_match.bytesize
          close_pos, close_size = find_close(tag_name)

          if close_pos
            element = element_class.new
            element << AST::Text.new(@input.byteslice(@pos, close_pos - @pos))
            @parent << element
            @pos = close_pos + close_size
          else
            @text_buffer << full_match
          end
        end

        # Handle paired formatting tags like <s>, <u>, <sup>, <sub>.
        # Content inside IS parsed for wiki markup.
        def handle_paired_tag(tag_name, full_match, element_class)
          @pos += full_match.bytesize
          close_pos, close_size = find_close(tag_name)

          if close_pos
            element = element_class.new
            parse_inner_content(@input.byteslice(@pos, close_pos - @pos), parent: element)
            @parent << element
            @pos = close_pos + close_size
          else
            @text_buffer << full_match
          end
        end

        # The end tag of +tag_name+ behind the cursor, in any case:
        # MediaWiki reads `</S>` like `</s>`.
        #
        # @param tag_name [String] letters only, see HTML_TAG_AT_CURSOR
        # @return [Array(Integer, Integer), nil] its position and size
        def find_close(tag_name)
          position = @input.byteindex(%r{</#{tag_name}>}i, @pos)
          [position, Regexp.last_match(0).bytesize] if position
        end

        # Flush accumulated text buffer to the parent as a Text node.
        # AST::Text copies the (mutable) buffer, so clearing it afterwards
        # reuses the allocated capacity for the next span.
        def flush_text
          return if @text_buffer.empty?

          @parent << AST::Text.new(@text_buffer)
          @text_buffer.clear
        end
      end
    end
  end
end
