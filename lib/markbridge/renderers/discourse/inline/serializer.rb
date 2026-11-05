# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      module Inline
        # Writes inline tokens (see {Tokens}) as Markdown, or as HTML inside
        # an HTML block. It is the one place that knows what stands on both
        # sides of a piece of output: which backtick run a code span needs,
        # where the markers of an emphasis go when its content starts with
        # whitespace, whether a bare URL can stay bare or has to be written
        # as a link, and what a join between two pieces needs ({Joins}).
        #
        # Tokens are written in groups, one per child of the element being
        # rendered, so a tag can still change the buffer in front of a
        # child (see {#write_groups}). A child's output that is a String
        # instead of tokens is finished Markdown from a tag and is written
        # as it is.
        class Serializer
          # Per delimiter: the opening and closing marker, the HTML tags for
          # an HTML block, the character whose run makes the marker, and
          # whether a nested pair of that character at one edge of the
          # content is fine. Content with the marker in it, or with the
          # character at an edge where it would join the marker into a
          # longer run, cannot be wrapped and gets the HTML tags instead.
          # For emphasis a nested pair at one edge still works (`***a* b**`
          # is strong), at both edges it does not. For strikethrough three
          # tildes are no marker at all. The BBCode underline has no such
          # character, Discourse reads it with its own rule.
          DELIMITERS = {
            strong: %w[** ** <strong> </strong> *],
            em: %w[* * <em> </em> *],
            s: %w[~~ ~~ <s> </s> ~],
            u: ["[u]", "[/u]", %(<span class="bbcode-u">), "</span>", nil],
          }.freeze

          # Whitespace and <br> only: nothing a marker could wrap.
          NOTHING_TO_WRAP = /\A(?:[[:space:]]|<br>)*\z/
          # Leading or trailing whitespace, Unicode-aware: CommonMark's
          # flanking rules treat a no-break space as whitespace too.
          EDGES = /\A([[:space:]]*)(.+?)([[:space:]]*)\z/m

          # Text after a bare URL glues to it, unless it starts with
          # whitespace or with sentence punctuation that is followed by
          # whitespace or nothing: markdown-it (linkify) leaves one `,`, or
          # a run of `.`, `!` or `?`, out of the link. It keeps a `:` in the
          # link, and the first character of a mixed run like `.)` or `?!`.
          # A `)` may come first, but only when the href has no parenthesis
          # of its own: linkify counts them and keeps a `)` that closes one
          # in the link.
          GLUED_AFTER = /\A(?!(?:\.+|!+|\?+|,)?(?:[[:space:]]|\z))/
          GLUED_AFTER_PAREN_OK = /\A(?!\)?(?:\.+|!+|\?+|,)?(?:[[:space:]]|\z))/
          PARENTHESIS = /[()]/
          # The character in front of a bare URL keeps it from being linked
          # unless it is whitespace or an opening parenthesis.
          NOT_GLUED_BEFORE = /[[:space:](]/
          # What markdown-it's linkify links on its own: a web or FTP URL
          # with its scheme, or a mail address with mailto:. A relative
          # href, an anchor or a protocol-relative URL only links as a
          # Markdown link.
          AUTOLINKABLE = %r{\A(?:https?://|ftps?://|mailto:)}i
          # An href that is no URL but a place on the site: a path, an
          # anchor, a query. Such a bare link is written as a Markdown
          # link. A target that is neither, a wiki page name for example,
          # stays plain text: a link to it would be broken anyway, and a
          # consumer maps such targets to real URLs on the AST.
          PATH_LIKE = %r{\A(?:[/#?]|\.{1,2}/)}

          BACKTICKS = /`+/
          # Breaks written as <br> at the end of a group, after the newline
          # of the break in front of them.
          TRAILING_BREAKS = /\n<br>(?:\n|<br>)*\z/
          # Spaces and tabs at the start of a piece. Not a no-break space:
          # the escaper writes one where it wants indentation kept.
          LEADING_BLANKS = /\A[ \t]+/
          NEWLINE = 10
          SPACE = 32
          TAB = 9
          LT = 60
          # Whitespace with a line break in it, see #flat_alt.
          ALT_LINE_BREAK = /[[:space:]]*\n[[:space:]]*/
          # The parts after a `|` in the alt text that Discourse reads as
          # image options: a size (`100x100`, `100x100, 50%`), a media type
          # or `thumbnail`, and a data attribute (`key=value`). Spelled
          # after isKnownImageSuffix in Discourse's markdown-it engine.
          DISCOURSE_OPTION =
            /\A(?:[1-9][0-9]*x[1-9][0-9]*(?:[[:space:]]*,[[:space:]]*x?[1-9][0-9]{0,2}[%x]?)?|video|audio|thumbnail)\z/
          DATA_ATTRIBUTE = /\A[\w\-:.]*=/

          private_constant :NOTHING_TO_WRAP,
                           :EDGES,
                           :GLUED_AFTER,
                           :GLUED_AFTER_PAREN_OK,
                           :PARENTHESIS,
                           :NOT_GLUED_BEFORE,
                           :AUTOLINKABLE,
                           :PATH_LIKE,
                           :BACKTICKS,
                           :LEADING_BLANKS,
                           :TRAILING_BREAKS,
                           :NEWLINE,
                           :SPACE,
                           :TAB,
                           :LT,
                           :ALT_LINE_BREAK,
                           :DISCOURSE_OPTION,
                           :DATA_ATTRIBUTE

          # @param escaper [#escape] escapes text for Markdown, see
          #   {MarkdownEscaper#escape}
          # @param html_escaper [#escape] escapes text for HTML
          def initialize(escaper:, html_escaper: HtmlEscaper)
            @escaper = escaper
            @html_escaper = html_escaper
            # The buffer the last hard break went into as a newline, and
            # its length right after. A piece that starts with a newline
            # follows that break only while nothing else was written to or
            # taken off the buffer since.
            @break_buffer = nil
            @break_end = 0
          end

          # Writes one run of tokens.
          #
          # @param tokens [Array<Array>]
          # @param html_mode [Boolean] write HTML for an HTML block
          # @return [String]
          def write(tokens, html_mode: false)
            buffer = +""
            pending = write_tokens(buffer, tokens, 0, tokens.size, html_mode, nil)
            Joins.append(buffer, bare_url_piece(pending, buffer, nil)) if pending
            drop_trailing_breaks(buffer, html_mode)
          end

          # Writes the output of several children one after the other. The
          # block gives the output of each child, finished Markdown or
          # tokens, as it is reached. +before+ runs right before the first
          # piece of a child's output is appended, with the buffer so far
          # and the child; it may change the buffer in place. A child
          # whose output is empty is skipped.
          #
          # @param children [Array] the children
          # @param html_mode [Boolean]
          # @param before [Proc, nil] called with the buffer and the child
          # @yieldparam child [Object]
          # @yieldreturn [String, Array<Array>] the child's output
          # @return [String]
          def write_groups(children, html_mode: false, before: nil)
            buffer = +""
            # A bare URL at the end of an output waits for the first piece
            # of the next output that has one.
            pending = nil
            children.each do |child|
              output = yield(child)
              if output.instance_of?(String)
                next if output.empty?

                # The hook may take whitespace off the buffer, so the piece
                # is fitted to the line after it ran, and after a waiting
                # bare URL was written: it follows the URL, not the line.
                pending = settle(buffer, pending, output)
                before&.call(buffer, child)
                output = start_of_line(buffer, output) unless html_mode
                next if output.empty?

                html_mode ? buffer << output : Joins.append(buffer, output)
              else
                pending =
                  write_tokens(buffer, output, 0, output.size, html_mode, pending, before, child)
              end
            end
            Joins.append(buffer, bare_url_piece(pending, buffer, nil)) if pending
            drop_trailing_breaks(buffer, html_mode)
          end

          private

          # A break written as <br> protected the line it ended against the
          # newline of the next piece. Nothing follows in this group, so at
          # its end the <br> protects nothing and goes, like the whitespace
          # a block tag takes off its content. In an HTML block a break is
          # <br> on its own, and stays.
          def drop_trailing_breaks(buffer, html_mode)
            buffer.sub!(TRAILING_BREAKS, "\n") if !html_mode && buffer.include?("<br>")
            buffer
          end

          # Writes the tokens from +from+ up to +to+ into +buffer+, one piece
          # at a time, each joined with what stands in front of it. A
          # delimiter pair or a link is one piece with its content written
          # first. A bare URL is not written at once: it waits for the next
          # piece, which decides its form, and is returned as +pending+
          # when the tokens end with it. +before+ runs with +child+ right
          # before the first piece of these tokens is written.
          #
          # @return [String, nil] the href of a bare URL that still waits
          def write_tokens(
            buffer,
            tokens,
            from,
            to,
            html_mode,
            pending,
            before = nil,
            child = nil,
            blank: 0
          )
            index = from
            while index < to
              token = tokens.fetch(index)
              index += 1
              kind = nil
              moved_break = false
              if token.instance_of?(String)
                piece = token
              else
                kind, value = token
                piece =
                  case kind
                  when Tokens::TEXT
                    text_piece(token, html_mode)
                  when Tokens::HTML
                    value
                  when Tokens::OPEN
                    close =
                      matching_close(tokens, index - 1, to, Tokens::OPEN, Tokens::CLOSE, value)
                    content =
                      run(tokens, index, close, html_mode, trailing_blank_lines(buffer, blank))
                    # A break at the end of the content moves out of the
                    # markers with its newline.
                    moved_break = after_break?(content)
                    nested = nested_pairs(tokens, index, close)
                    index = close + 1
                    delimiter_piece(value, content, html_mode, nested)
                  when Tokens::LINK_OPEN
                    close =
                      matching_close(tokens, index - 1, to, Tokens::LINK_OPEN, Tokens::LINK_CLOSE)
                    content =
                      run(tokens, index, close, html_mode, trailing_blank_lines(buffer, blank))
                    moved_break = after_break?(content)
                    index = close + 1
                    link_piece(value, content, html_mode)
                  when Tokens::CODE
                    code_piece(value, html_mode)
                  when Tokens::BARE_URL
                    if html_mode
                      html_link(value, @html_escaper.escape(value))
                    else
                      # Settled with the piece after it, or with nothing.
                      pending = settle(buffer, pending, token)
                      if before
                        before.call(buffer, child)
                        before = nil
                      end
                      pending = value
                      next
                    end
                  when Tokens::IMAGE
                    image_piece(token, html_mode)
                  when Tokens::HARD_BREAK
                    html_mode ? "<br>" : hard_break_piece(trailing_blank_lines(buffer, blank))
                  when Tokens::CLOSE, Tokens::LINK_CLOSE
                    raise ArgumentError, "#{kind} token without an open token in front of it"
                  else
                    raise ArgumentError, "unknown inline token #{token.inspect}"
                  end
              end
              next if piece.empty?

              pending = settle(buffer, pending, piece)
              if before
                before.call(buffer, child)
                before = nil
              end
              piece = start_of_line(buffer, piece, blank) unless html_mode
              next if piece.empty?

              html_mode ? buffer << piece : Joins.append(buffer, piece)
              # A break written as a newline, or one that left a run at
              # its end, is where a newline at the start of the next piece
              # would make a blank line.
              if (kind == Tokens::HARD_BREAK || moved_break) && piece.end_with?("\n")
                @break_buffer = buffer
                @break_end = buffer.bytesize
              end
            end
            pending
          end

          # A piece that starts a line. Spaces at its start after a blank
          # line go: a block ended there, and spaces at the start of the
          # next line would pull the paragraph after them into that block.
          # A newline at its start right after a hard break becomes <br>,
          # as the break itself would be on a line that holds nothing
          # else; two newlines are a blank line the text brings on
          # purpose. What is left may be nothing, which the caller skips.
          def start_of_line(buffer, piece, blank = 0)
            first = piece.getbyte(0)
            if first == NEWLINE
              return piece unless after_break?(buffer) && piece.getbyte(1) != NEWLINE

              "<br>#{piece.byteslice(1, piece.bytesize - 1)}"
            else
              blanks = first == SPACE || first == TAB
              return piece unless blanks && trailing_blank_lines(buffer, blank) == 2

              piece.sub(LEADING_BLANKS, "")
            end
          end

          def after_break?(buffer)
            buffer.equal?(@break_buffer) && buffer.bytesize == @break_end
          end

          # Nothing but whitespace and <br>, or nothing at all. The regex
          # runs only when the first character lets it match; a regex over
          # the whole content scans it for its encoding first.
          def nothing_to_wrap?(content)
            first = content.getbyte(0)
            return true if first.nil?
            return false unless first == LT || Joins.space_at?(content, 0)

            content.match?(NOTHING_TO_WRAP)
          end

          # Whitespace at the start or at the end of the content, checked on
          # the two characters alone.
          def edge_whitespace?(content)
            Joins.space_at?(content, 0) || Joins.space_at?(content, Joins.last_char_index(content))
          end

          # How many of the lines at the end of the buffer hold nothing but
          # spaces and tabs, up to two. +blank+ is the count in front of
          # the buffer: for a nested run, the count of the outer buffer it
          # is written into.
          def trailing_blank_lines(buffer, blank)
            lines = 0
            index = buffer.bytesize - 1
            while index >= 0
              byte = buffer.getbyte(index)
              if byte == NEWLINE
                lines += 1
                return lines if lines == 2
              elsif byte != SPACE && byte != TAB
                return lines
              end
              index -= 1
            end
            [lines + blank, 2].min
          end

          # A newline. On a line that holds nothing else it is <br>: a
          # newline there would be a blank line, which ends the paragraph
          # and makes a list loose, while <br> keeps the empty line inside
          # the paragraph. After a blank line the break is nothing, the
          # paragraph has ended there already.
          def hard_break_piece(blank_lines)
            case blank_lines
            when 0
              "\n"
            when 1
              "<br>"
            else
              ""
            end
          end

          # Writes a waiting bare URL now that +following+, the piece after
          # it, is known. Another bare URL as +following+ glues like text.
          # @return [nil]
          def settle(buffer, pending, following)
            Joins.append(buffer, bare_url_piece(pending, buffer, following)) if pending
            nil
          end

          # The index of the +close_kind+ token that ends the +open_kind+
          # token at +from+. A pair of the same kind, and for delimiters
          # the same name, in between is skipped.
          def matching_close(tokens, from, to, open_kind, close_kind, name = nil)
            depth = 0
            index = from + 1
            while index < to
              kind, value = tokens.fetch(index)
              if name.nil? || value == name
                if kind == open_kind
                  depth += 1
                elsif kind == close_kind
                  return index if depth.zero?

                  depth -= 1
                end
              end
              index += 1
            end
            raise ArgumentError, "#{open_kind} token without a #{close_kind} token after it"
          end

          NO_PAIRS = [false, false, false].freeze
          private_constant :NO_PAIRS

          # Whether the content between +from+ and +to+ starts with a
          # nested delimiter pair, ends with one, and whether that is one
          # pair spanning the whole content.
          def nested_pairs(tokens, from, to)
            first = tokens.fetch(from)
            last = tokens.fetch(to - 1)
            at_start = !first.instance_of?(String) && first.first == Tokens::OPEN
            at_end = !last.instance_of?(String) && last.first == Tokens::CLOSE
            return NO_PAIRS unless at_start || at_end

            spanning =
              at_start && at_end &&
                matching_close(tokens, from, to, Tokens::OPEN, Tokens::CLOSE, first.fetch(1)) ==
                  to - 1
            [at_start, at_end, spanning]
          end

          # The content between an open and a close token, written on
          # its own. Its pieces are joined among themselves; what stands
          # outside the pair is not known here, as a tag that returned a
          # String would not know it either.
          def run(tokens, from, to, html_mode, blank)
            single_string(tokens, from, to) || joined(tokens, from, to, html_mode, blank)
          end

          def joined(tokens, from, to, html_mode, blank)
            buffer = +""
            pending = write_tokens(buffer, tokens, from, to, html_mode, nil, blank:)
            Joins.append(buffer, bare_url_piece(pending, buffer, nil)) if pending
            buffer
          end

          # One String between the tokens is the whole content, the common
          # case: nothing to join, no buffer to fill. nil otherwise.
          def single_string(tokens, from, to)
            return unless to - from == 1

            token = tokens.fetch(from)
            token if token.instance_of?(String)
          end

          def text_piece(token, html_mode)
            _, string, mode = token
            return HtmlBlock.without_blank_lines(@html_escaper.escape(string)) if html_mode

            case mode
            when Tokens::ESCAPE
              @escaper.escape(string)
            when Tokens::LABEL
              @escaper.escape(string, in_link_label: true)
            else
              string
            end
          end

          # Content with nothing visible in it keeps no markers. Whitespace
          # at the edges stays outside the markers and outside the HTML
          # tags: a marker next to whitespace does not open or close, and
          # an HTML tag alone on its line opens an HTML block. A BBCode tag
          # keeps the whitespace inside, Discourse has no such rule.
          # Content that would break the marker gets the HTML tags.
          # +nested+ says whether a nested pair stands at the start, at
          # the end, and whether that is one pair spanning the content.
          def delimiter_piece(name, content, html_mode, nested)
            return content if nothing_to_wrap?(content)

            open, close, html_open, html_close, char = DELIMITERS.fetch(name)
            return "#{html_open}#{content}#{html_close}" if html_mode

            if char && edge_whitespace?(content)
              match = content.match(EDGES)
              lead = match[1]
              core = match[2]
              trail = match[3]
            else
              lead = trail = ""
              core = content
            end

            if char && breaks_marker?(core, open, char, nested)
              "#{lead}#{html_open}#{core}#{html_close}#{trail}"
            else
              core = escape_colon(core) if open.start_with?("[")
              "#{lead}#{open}#{keep_backslash(core)}#{close}#{trail}"
            end
          end

          # The marker in the content, or its character at an edge where
          # it would join the marker into a longer run. For emphasis the
          # character may come from a nested pair at that edge, and one
          # pair may span the content (`***a* b**` and `***a***` are
          # strong), but two pairs at the two edges are not
          # (`***a*<!---->*.***` does not cook as strong). For
          # strikethrough any tilde at an edge breaks the marker: a nested
          # strikethrough brings the `~~` marker itself into the content.
          # An escaped character at the end does not count: `\\*` is text.
          def breaks_marker?(core, marker, char, nested)
            return true if core.include?(marker)

            at_start = core.start_with?(char)
            at_end = core.end_with?(char) && !Joins.escaped_end?(core)
            pair_start, pair_end, spanning = nested
            (at_start && !pair_start) || (at_end && !pair_end) || (at_start && at_end && !spanning)
          end

          # A BBCode tag at the start of a line with a `:` right after it
          # reads as a link reference definition (`[u]:x`), the backslash
          # keeps the colon text.
          def escape_colon(core)
            core.start_with?(":") ? "\\#{core}" : core
          end

          # An odd run of backslashes at the end of the content would
          # escape the closing marker, one more backslash keeps the run
          # even.
          def keep_backslash(core)
            core.end_with?("\\") && !Joins.escaped_end?(core) ? "#{core}\\" : core
          end

          # Content without whitespace at its edges, the common case, takes
          # the plain interpolation.
          def place_markers(content, open, close)
            return "#{open}#{keep_backslash(content)}#{close}" unless edge_whitespace?(content)

            match = content.match(EDGES)
            "#{match[1]}#{open}#{keep_backslash(match[2])}#{close}#{match[3]}"
          end

          def link_piece(destination, content, html_mode)
            return html_link(destination, content) if html_mode
            return content unless Joins.visible?(content)

            place_markers(content, "[", "](#{LinkDestination.escape(destination)})")
          end

          def html_link(destination, content)
            %(<a href="#{@html_escaper.escape(destination)}">#{content}</a>)
          end

          # A bare URL is linked by the Markdown parser on its own only when
          # it has a scheme linkify knows, whitespace (or the start of the
          # line) stands in front of it and nothing sticks to its end.
          # Otherwise it is written as a Markdown link with the URL as its
          # text, which links everywhere, unless the href is no URL and no
          # path (see PATH_LIKE). The label is the href escaped for a link
          # label: a raw `]` in it would end the label early.
          def bare_url_piece(href, buffer, following)
            if AUTOLINKABLE.match?(href)
              return href unless glued_before?(buffer) || glued_after?(following, href)
            elsif !PATH_LIKE.match?(href)
              return href
            end

            "[#{@escaper.escape(href, in_link_label: true)}](#{LinkDestination.escape(href)})"
          end

          # Whether the buffer ends in something other than whitespace or
          # an opening parenthesis.
          def glued_before?(buffer)
            last = buffer[-1]
            !last.nil? && !last.match?(NOT_GLUED_BEFORE)
          end

          # Another bare URL right after this one is written as a link
          # itself and glues like any text.
          def glued_after?(following, href)
            return false if following.nil?
            return true unless following.instance_of?(String)

            following.match?(href.match?(PARENTHESIS) ? GLUED_AFTER : GLUED_AFTER_PAREN_OK)
          end

          # The delimiter is one backtick longer than the longest backtick
          # run in the content. A space on each side keeps a backtick at
          # the edge of the content away from the delimiter. Content that
          # starts and ends with a space gets the same padding, because
          # CommonMark strips one space from each end of such a span.
          def code_piece(content, html_mode)
            return "" if content.empty?
            return "<code>#{@html_escaper.escape(content)}</code>" if html_mode

            delimiter = "`" * (longest_run(content) + 1)
            padding = " " if needs_padding?(content)
            "#{delimiter}#{padding}#{content}#{padding}#{delimiter}"
          end

          def longest_run(content)
            content.scan(BACKTICKS).map(&:length).max || 0
          end

          def needs_padding?(content)
            return true if content.start_with?("`") || content.end_with?("`")

            # A span of spaces only is not stripped by CommonMark, so it
            # needs no padding.
            content.start_with?(" ") && content.end_with?(" ") &&
              content.count(" ") < content.length
          end

          # `![alt|WIDTHxHEIGHT](src)`, `![alt|WIDTH](src)` or `![alt](src)`.
          # A height alone means nothing to Discourse.
          def image_piece(token, html_mode)
            _, src, alt, width, height = token
            alt = flat_alt(alt)
            return image_html(src, alt, width, height) if html_mode

            size = ("#{width}x#{height}" if width && height) || width
            label = @escaper.escape(alt, in_link_label: true)
            "![#{label}#{"|" if ends_in_option?(alt)}#{"|#{size}" if size}](#{LinkDestination.escape(src)})"
          end

          # A blank line in the alt text would end the paragraph, and with
          # it the image. The line breaks go, the words stay apart.
          def flat_alt(alt)
            alt&.gsub(ALT_LINE_BREAK, " ")
          end

          # Discourse walks the `|` parts of the alt text from the right and
          # takes every part that looks like an option as one, up to the
          # first part that does not. A backslash does not stop that, the
          # alt text is unescaped first. When the alt text itself ends in
          # such a part, an empty part after it stops the walk there: the
          # options we write still apply, the alt text keeps its last part
          # and gets a `|` at its end.
          def ends_in_option?(alt)
            index = alt&.rindex("|")
            return false if index.nil?

            last = alt[(index + 1)..]
            DISCOURSE_OPTION.match?(last) || DATA_ATTRIBUTE.match?(last)
          end

          def image_html(src, alt, width, height)
            attrs = %(src="#{@html_escaper.escape(src)}" alt="#{@html_escaper.escape(alt)}")
            attrs << %( width="#{width}") if width
            attrs << %( height="#{height}") if height
            "<img #{attrs}>"
          end
        end
      end
    end
  end
end
