# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Renders AST to Discourse-flavored Markdown in-memory.
      class Renderer
        attr_reader :postprocessor

        def initialize(tag_library: nil, escaper: nil, html_escaper: nil, postprocessor: nil)
          @tag_library = tag_library || TagLibrary.shared_default
          @escaper = escaper || MarkdownEscaper.new
          @html_escaper = html_escaper || HtmlEscaper
          @postprocessor = postprocessor || Postprocessor::DEFAULT
          # @interface_cache, @resolved_tags, and @resolved_default_tags
          # are lazily initialized during a top-level #render /
          # #render_default call and reset to nil after the call completes.
        end

        # Render a node to Markdown
        # @param node [AST::Node]
        # @param context [RenderContext] rendering context with parent chain
        # @return [String]
        # @raise [TypeError] when the tag bound to the node's class returns
        #   something other than a String (a nil from a custom tag would
        #   otherwise surface as an inscrutable concatenation error deep
        #   inside render_children)
        def render(node, context: RenderContext.new)
          root_call = @interface_cache.nil?
          @interface_cache = {} if root_call

          # Exact-class hit first (a single Hash lookup, the common case),
          # then the memoized ancestry fallback so a subclass without its
          # own tag renders through its nearest ancestor's tag.
          tag = @tag_library[node.class] || resolved_tag(node.class)
          if tag
            result = tag.render(node, interface_for(context))
            unless result.is_a?(String)
              raise TypeError,
                    "#{tag.class} rendered #{node.class} to " \
                      "#{result.inspect} — tags must return a String " \
                      "(use interface.render_default(node) to fall back " \
                      "to the stock rendering)"
            end
            return result
          end

          render_without_tag(node, context)
        ensure
          if root_call
            @interface_cache = nil
            @resolved_tags = nil
            @resolved_default_tags = nil
          end
        end

        # Render a node with the stock tag for its class, ignoring any
        # override registered in this renderer's tag library. Lets a
        # custom tag intercept only the nodes it cares about and delegate
        # the rest:
        #
        #   library.register(AST::Quote, Tag.new do |node, interface|
        #     next interface.render_default(node) unless node.username&.start_with?("legacy_")
        #     ...custom rendering...
        #   end)
        #
        # Children still render through this renderer, so overrides for
        # other node classes keep applying inside the delegated subtree.
        #
        # @param node [AST::Node]
        # @param context [RenderContext] rendering context with parent chain
        # @return [String]
        def render_default(node, context: RenderContext.new)
          root_call = @interface_cache.nil?
          @interface_cache = {} if root_call

          tag = default_tag_library[node.class] || resolved_default_tag(node.class)
          return tag.render(node, interface_for(context)) if tag

          render_without_tag(node, context)
        ensure
          if root_call
            @interface_cache = nil
            @resolved_tags = nil
            @resolved_default_tags = nil
          end
        end

        # Render all children of a node
        #
        # With a block, the block runs at every join point, right before
        # a non-empty child output is appended. It receives the buffer
        # built so far and the child about to be rendered into it, and
        # may change the buffer in place. A tag uses this to adjust the
        # text in front of a specific child without iterating the
        # children itself, which would lose the emphasis-boundary rule
        # below.
        #
        # @param node [AST::Element]
        # @param context [RenderContext] rendering context
        # @yieldparam result [String] the buffer built so far
        # @yieldparam child [AST::Node] the child about to be appended
        # @return [String]
        # @example Attach a nested list directly to the text in front of it
        #   interface.render_children(item, context:) do |buffer, child|
        #     buffer.rstrip! if child.is_a?(AST::List)
        #   end
        def render_children(node, context:)
          result = +""
          node.children.each do |child|
            part = render(child, context:)
            next if part.empty?

            yield(result, child) if block_given?
            join(result, part)
            result << part
          end
          result
        end

        private

        # Inserted between sibling outputs when their adjacent characters
        # would merge into a longer Markdown emphasis delimiter run (e.g.
        # `***` + `*...` becoming `****...`). The HTML comment is invisible
        # in rendered output but breaks the delimiter run during Markdown
        # parsing.
        EMPHASIS_BOUNDARY = "<!---->"
        # Bytes where adjacent runs merge into a single longer run during
        # Markdown parsing: emphasis (* _), strikethrough (~), code spans (`).
        EMPHASIS_DELIMITER_BYTES = Set[42, 95, 126, 96].freeze
        # Delimiters that open and close only where CommonMark's flanking
        # rules allow it: emphasis (* _) and strikethrough (~), with the
        # pattern that finds the first byte outside a run of each.
        FLANKING_DELIMITERS = { 42 => /[^*]/, 95 => /[^_]/, 126 => /[^~]/ }.freeze
        BACKSLASH = 92
        BANG = 33
        BRACKET_OPEN = 91
        UNDERSCORE = 95
        TILDE = 126

        # What a byte is to the flanking rules. WORD: ASCII letters and
        # digits, and every non-ASCII byte (a few Unicode punctuation marks
        # are then handled like letters, which costs a comment that changes
        # nothing). PUNCTUATION: ASCII punctuation as CommonMark defines
        # it, the backslash included, which is what makes an escaped
        # character at the edge of an emphasis count as punctuation.
        # DELIMITER: `*`, `_` and `~`. The table is a 256-byte string read
        # with getbyte, so the check per sibling is two byte reads instead
        # of a chain of comparisons.
        OTHER = 0
        WORD = 1
        PUNCTUATION = 2
        DELIMITER = 3
        BYTE_CLASSES =
          Array
            .new(256) do |byte|
              if FLANKING_DELIMITERS.key?(byte)
                DELIMITER
              elsif byte >= 128 || byte.between?(48, 57) || byte.between?(65, 90) ||
                    byte.between?(97, 122)
                WORD
              elsif byte.between?(33, 47) || byte.between?(58, 64) || byte.between?(91, 96) ||
                    byte.between?(123, 126)
                PUNCTUATION
              else
                OTHER
              end
            end
            .pack("C*")
            .freeze
        private_constant :EMPHASIS_BOUNDARY,
                         :EMPHASIS_DELIMITER_BYTES,
                         :FLANKING_DELIMITERS,
                         :BACKSLASH,
                         :BANG,
                         :BRACKET_OPEN,
                         :UNDERSCORE,
                         :TILDE,
                         :OTHER,
                         :WORD,
                         :PUNCTUATION,
                         :DELIMITER,
                         :BYTE_CLASSES

        # Adjusts the end of +result+ where the next +part+ would change
        # how the two sides are read together. Runs once per sibling, so
        # the common case (nothing to do) is decided from the two edge
        # bytes alone. On an empty buffer getbyte returns nil, which
        # matches no byte of a non-empty part.
        def join(result, part)
          last_byte = result.getbyte(-1)
          first_byte = part.getbyte(0)

          if last_byte == first_byte && EMPHASIS_DELIMITER_BYTES.include?(last_byte)
            result << EMPHASIS_BOUNDARY
          elsif last_byte == BANG && first_byte == BRACKET_OPEN
            # A `!` right in front of a link makes it an image. The escaper
            # leaves a lone `!` alone because it cannot see the next node.
            result.insert(-2, "\\") unless escaped_bang?(result)
          elsif last_byte && blocked_flanking?(result, last_byte, part, first_byte)
            result << EMPHASIS_BOUNDARY
          end
        end

        # Whether the delimiter run on one side of the join cannot open or
        # close because of what stands on the other side (CommonMark 6.2).
        # A run at the start of +part+ cannot open when a word character
        # stands in front of it and punctuation follows it: `item*\#*` stays
        # literal text. The mirror image holds for a run at the end of
        # +result+. A `_` run never opens after, or closes in front of, a
        # word character. The boundary comment between them is punctuation,
        # so the run can open or close again.
        def blocked_flanking?(result, last_byte, part, first_byte)
          last_class = BYTE_CLASSES.getbyte(last_byte)
          first_class = BYTE_CLASSES.getbyte(first_byte)

          if first_class == DELIMITER && blocking_neighbour?(last_byte, last_class)
            first_byte == UNDERSCORE || punctuation?(byte_after_run(part, first_byte))
          elsif last_class == DELIMITER && blocking_neighbour?(first_byte, first_class)
            last_byte == UNDERSCORE || punctuation?(byte_before_run(result, last_byte))
          end
        end

        # A word character, or a tilde. CommonMark counts `~` as punctuation,
        # but cmark-gfm (commonmarker) does not treat it as one next to an
        # emphasis delimiter, so strikethrough right next to emphasis with a
        # punctuation edge needs the boundary as well. markdown-it would not
        # need it; the comment changes nothing there.
        def blocking_neighbour?(byte, byte_class)
          byte_class == WORD || byte == TILDE
        end

        # A delimiter is punctuation too; it has its own class only so that
        # the join can spot it in one read.
        def punctuation?(byte)
          return false if byte.nil?

          byte_class = BYTE_CLASSES.getbyte(byte)
          byte_class == PUNCTUATION || byte_class == DELIMITER
        end

        # The first byte after the run of +byte+ that starts +part+, nil
        # when the part is nothing but the run.
        def byte_after_run(part, byte)
          index = part.byteindex(FLANKING_DELIMITERS.fetch(byte))
          index && part.getbyte(index)
        end

        # The byte in front of the run of +byte+ that ends +result+, nil
        # when the run reaches the start of the buffer.
        def byte_before_run(result, byte)
          index = result.byterindex(FLANKING_DELIMITERS.fetch(byte))
          index && result.getbyte(index)
        end

        # Whether the `!` at the end of +result+ is escaped. Only an odd
        # run of backslashes escapes it: `\\!` is an escaped backslash
        # followed by an active `!`. When the run reaches the start of the
        # buffer the index turns negative and getbyte wraps around to the
        # `!` at the end, which stops the loop.
        def escaped_bang?(result)
          escaped = false
          index = result.bytesize - 2
          while result.getbyte(index) == BACKSLASH
            escaped = !escaped
            index -= 1
          end
          escaped
        end

        def interface_for(context)
          @interface_cache[context.object_id] ||= RenderingInterface.new(self, context)
        end

        # Ancestry fallback for tag dispatch (see TagLibrary#resolve),
        # memoized per top-level render call — the tag library can change
        # between calls, so the cache must not outlive one call (it is
        # reset in #render's ensure). +fetch+ stores nil results too, so a
        # class that resolves to no tag is walked once per call, not once
        # per node.
        def resolved_tag(node_class)
          cache = @resolved_tags ||= {}
          cache.fetch(node_class) { cache[node_class] = @tag_library.resolve(node_class) }
        end

        # Same as {#resolved_tag}, against the default library backing
        # #render_default.
        def resolved_default_tag(node_class)
          cache = @resolved_default_tags ||= {}
          cache.fetch(node_class) { cache[node_class] = default_tag_library.resolve(node_class) }
        end

        # Pristine default library backing #render_default. Built lazily —
        # most renders never need it.
        def default_tag_library
          @default_tag_library ||= TagLibrary.default
        end

        # The tag-less rendering paths shared by #render and #render_default.
        # An element without a tag does not go on the parent chain (every
        # chain walk would get one step longer, and text nodes walk it
        # several times). The first one becomes the context's root element
        # instead, so top-level children can still ask for their siblings.
        # The Document is the usual case.
        def render_without_tag(node, context)
          case node
          when AST::Element # Document is an Element subclass
            context = context.with_root(node) if context.root.nil?
            render_children(node, context:)
          when AST::MarkdownText
            render_markdown_text(node, context)
          when AST::Text
            render_text(node, context)
          else
            ""
          end
        end

        # In html_mode, surround pre-formatted Markdown with blank lines so that
        # CommonMark terminates the enclosing HTML block (e.g. <table>) and
        # parses the content as Markdown before the closing tags reopen another
        # HTML block.
        def render_markdown_text(node, context)
          context.html_mode? ? HtmlBlock.island(node.text) : node.text
        end

        def render_text(node, context)
          in_code, in_link_label = text_ancestry(context)

          # In html_mode even inside a code block we must HTML-escape, otherwise a
          # stray `<` in a code cell would break the surrounding <td>.
          if in_code
            context.html_mode? ? @html_escaper.escape(node.text) : node.text
          elsif context.html_mode?
            @html_escaper.escape(node.text)
          else
            @escaper.escape(node.text, in_link_label:)
          end
        end

        # Whether the text has a Code ancestor, and whether it has a link
        # label ancestor, found in one walk up the parent chain. Text nodes
        # are the most frequent nodes, and every step of the chain costs,
        # so the checks are spelled out instead of going through a block.
        #
        # A link label is where `]` is structural and must be escaped: a
        # link, a mail link, and the alt text of an image (ImageTag renders
        # it as a Text node under the Image). Tags that emit their own
        # bracketed markup (ImageTag, UploadTag, etc.) skip the text path
        # entirely, so their structural brackets are preserved.
        # @return [Array(Boolean, Boolean)]
        def text_ancestry(context)
          in_code = false
          in_link_label = false

          # The chain always ends in a root context whose element is nil.
          while (parent = context.element)
            in_code = true if parent.is_a?(AST::Code)
            in_link_label = true if parent.is_a?(AST::Url) || parent.is_a?(AST::Email) ||
              parent.is_a?(AST::Image)
            context = context.parent_context
          end

          [in_code, in_link_label]
        end
      end
    end
  end
end
