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
          outer_parent = @child_parent
          outer_index = @child_index
          outer_list = @previous_list
          @child_parent = node
          @previous_list = nil
          index = -1
          node.children.each do |child|
            @child_index = (index += 1)
            part = render(child, context:)
            next if part.empty?

            yield(result, child) if block_given?

            # The join rules are a table read from the class of the byte
            # in front of the join and the byte after it, so the common
            # case — nothing to do — costs four byte reads and no method
            # call. On an empty buffer getbyte returns nil and there is no
            # byte in front of the join, so the first child needs no guard
            # of its own.
            last_byte = result.getbyte(-1)
            if last_byte
              action =
                JOIN_ACTIONS.getbyte((BYTE_CLASSES.getbyte(last_byte) << 8) + part.getbyte(0))
              join(result:, part:, last_byte:, action:, context:) unless action == NOTHING
            end

            result << part

            # Remembers the last list among these children for
            # #previous_list. Text after it with something other than
            # whitespace in it keeps two lists apart; a child that renders
            # to nothing never gets here.
            if child.is_a?(AST::List)
              @previous_list = child
            elsif @previous_list && part.match?(VISIBLE)
              @previous_list = nil
            end
          end
          @child_parent = outer_parent
          @child_index = outer_index
          @previous_list = outer_list
          result
        end

        # The element whose children #render_children is rendering right
        # now. Unlike the parent chain of the context it also knows an
        # element without a tag of its own, which never goes on the chain.
        # @return [AST::Element, nil]
        attr_reader :child_parent

        # The position of the child that #render_children is rendering
        # right now, among the children of its parent. A nested call
        # sets it back when it returns, so a tag still finds its own
        # position after it rendered its children. Only a hint for
        # RenderingInterface#sibling, which checks it before use: a node
        # rendered on its own, outside #render_children, sees the
        # position of some other node.
        # @return [Integer, nil]
        attr_reader :child_index

        # The last list among the siblings in front of +element+, when
        # nothing but whitespace or nodes that rendered to nothing came
        # after it. nil when there is none, or when +element+ is not the
        # child that #render_children is rendering right now.
        # @param element [AST::Node]
        # @return [AST::List, nil]
        def previous_list(element)
          @previous_list if current_child?(element)
        end

        # Whether +element+ is the child that #render_children is
        # rendering right now. The state above describes that child only.
        # @param element [AST::Node]
        # @return [Boolean]
        def current_child?(element)
          parent = child_parent
          !parent.nil? && parent.children.at(child_index).equal?(element)
        end

        private

        # Inserted between sibling outputs when their adjacent characters
        # would merge into a longer Markdown emphasis delimiter run (e.g.
        # `***` + `*...` becoming `****...`). The HTML comment is invisible
        # in rendered output but breaks the delimiter run during Markdown
        # parsing.
        EMPHASIS_BOUNDARY = "<!---->"
        # Something other than whitespace.
        VISIBLE = /[^[:space:]]/
        # A punctuation character or a symbol right at the search start,
        # which is what CommonMark's flanking rules count as punctuation
        # (ASCII and Unicode alike), as markdown-it and cmark-gfm do.
        PUNCTUATION_AT = /\G[\p{P}\p{S}]/
        # Delimiters that open and close only where CommonMark's flanking
        # rules allow it: emphasis (* _) and strikethrough (~), with the
        # pattern that finds the first byte outside a run of each.
        FLANKING_DELIMITERS = { 42 => /[^*]/, 95 => /[^_]/, 126 => /[^~]/ }.freeze
        BACKSLASH = 92

        # What a byte is to the join rules. WORD: ASCII letters and
        # digits, and every non-ASCII byte. On the side of the join away
        # from a delimiter run, Unicode punctuation then goes through the
        # check like a letter, which at worst costs a comment that changes
        # nothing; on the side of the run the check reads the whole
        # character (#punctuation_at?). PUNCTUATION: ASCII punctuation as
        # CommonMark defines it, the backslash included, which is what makes an escaped
        # character at the edge of an emphasis count as punctuation. The
        # five bytes the rules name get a class of their own, so a class
        # tells them apart without a second comparison; they stay
        # punctuation, which is why they sit above PUNCTUATION.
        OTHER = 0
        WORD = 1
        PUNCTUATION = 2
        BANG = 3
        BRACKET = 4
        BACKTICK = 5
        STAR = 6
        UNDERSCORE = 7
        TILDE = 8
        CLASS_COUNT = 9
        # A 256-byte string read with getbyte, so classifying a byte is
        # one read instead of a chain of comparisons.
        BYTE_CLASSES =
          Array
            .new(256) do |byte|
              case byte
              when 33
                BANG
              when 42
                STAR
              when 91
                BRACKET
              when 95
                UNDERSCORE
              when 96
                BACKTICK
              when 126
                TILDE
              else
                if byte >= 128 || byte.between?(48, 57) || byte.between?(65, 90) ||
                     byte.between?(97, 122)
                  WORD
                elsif byte.between?(33, 47) || byte.between?(58, 64) || byte.between?(91, 96) ||
                      byte.between?(123, 126)
                  PUNCTUATION
                else
                  OTHER
                end
              end
            end
            .pack("C*")
            .freeze

        # What a join between two sibling outputs has to do.
        NOTHING = 0
        BOUNDARY = 1
        CHECK_AFTER = 2
        CHECK_BEFORE = 3
        ESCAPE_BANG = 4
        # Runs that merge into a single longer run during Markdown
        # parsing: emphasis (* _), strikethrough (~), code spans (`).
        MERGING_CLASSES = [STAR, UNDERSCORE, TILDE, BACKTICK].freeze
        # Runs that open and close only where the flanking rules allow it.
        FLANKING_CLASSES = [STAR, UNDERSCORE, TILDE].freeze

        # The action per join, in CLASS_COUNT rows of 256 bytes (2304 in
        # all), read with JOIN_ACTIONS.getbyte((class of the byte in front
        # << 8) + the byte after). Both sides of a join are a single byte
        # for every rule, so the whole decision fits in the table except
        # for the two cases that have to look past a delimiter run and the
        # one that has to count backslashes.
        #
        # A run at the start of the part cannot open when a word character
        # stands in front of it and punctuation follows it: `item*\#*`
        # stays literal text (CommonMark 6.2). The mirror image holds for
        # a run at the end of the buffer. A `_` run never opens after, or
        # closes in front of, a word character, so it needs no look past
        # the run. The boundary comment between the two sides is
        # punctuation, so the run can open or close again.
        #
        # A tilde counts as a blocking neighbor like a word character:
        # CommonMark reads `~` as punctuation, but cmark-gfm
        # (commonmarker) does not treat it as one next to an emphasis
        # delimiter, so strikethrough right next to emphasis with a
        # punctuation edge needs the boundary as well. markdown-it would
        # not need it; the comment changes nothing there.
        JOIN_ACTIONS =
          Array
            .new(CLASS_COUNT * 256) do |index|
              before = index >> 8
              after = BYTE_CLASSES.getbyte(index & 255)

              if before == after && MERGING_CLASSES.include?(before)
                BOUNDARY
              elsif before == BANG && after == BRACKET
                ESCAPE_BANG
              elsif FLANKING_CLASSES.include?(after) && (before == WORD || before == TILDE)
                after == UNDERSCORE ? BOUNDARY : CHECK_AFTER
              elsif FLANKING_CLASSES.include?(before) && (after == WORD || after == TILDE)
                before == UNDERSCORE ? BOUNDARY : CHECK_BEFORE
              else
                NOTHING
              end
            end
            .pack("C*")
            .freeze
        private_constant :EMPHASIS_BOUNDARY,
                         :VISIBLE,
                         :PUNCTUATION_AT,
                         :FLANKING_DELIMITERS,
                         :BACKSLASH,
                         :OTHER,
                         :WORD,
                         :PUNCTUATION,
                         :BANG,
                         :BRACKET,
                         :BACKTICK,
                         :STAR,
                         :UNDERSCORE,
                         :TILDE,
                         :CLASS_COUNT,
                         :BYTE_CLASSES,
                         :NOTHING,
                         :BOUNDARY,
                         :CHECK_AFTER,
                         :CHECK_BEFORE,
                         :ESCAPE_BANG,
                         :MERGING_CLASSES,
                         :FLANKING_CLASSES,
                         :JOIN_ACTIONS

        # Carries out the action the join table picked for the boundary
        # between +result+ and +part+. NOTHING never gets here — the
        # caller keeps it out — so the last branch is ESCAPE_BANG.
        def join(result:, part:, last_byte:, action:, context:)
          if action == BOUNDARY
            result << EMPHASIS_BOUNDARY
          elsif action == CHECK_AFTER
            index = part.byteindex(FLANKING_DELIMITERS.fetch(part.getbyte(0)))
            result << EMPHASIS_BOUNDARY if punctuation_at?(part, index:)
          elsif action == CHECK_BEFORE
            index = result.byterindex(FLANKING_DELIMITERS.fetch(last_byte))
            result << EMPHASIS_BOUNDARY if punctuation_at?(result, index:)
          elsif !context.html_mode? && !escaped_bang?(result)
            # A `!` right in front of a link makes it an image. The escaper
            # leaves a lone `!` alone because it cannot see the next node.
            # Inside an HTML block nothing is Markdown, a backslash would
            # show. Byte offsets: the `!` is the last byte.
            result.bytesplice(result.bytesize - 1, 0, "\\")
          end
        end

        # Whether the character at byte +index+ of +string+ is punctuation
        # for the flanking rules. +index+ is the start of a character (the
        # searches that find it match whole characters), nil when there is
        # no character, which is no punctuation. The match is anchored at
        # +index+ and reads the whole character, so it needs no copy.
        # @param string [String]
        # @param index [Integer, nil]
        # @return [Boolean]
        def punctuation_at?(string, index:)
          return false if index.nil?

          !string.byteindex(PUNCTUATION_AT, index).nil?
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

        # Text nodes are the most frequent nodes, so this walks the parent
        # chain once and takes the first answer it can: in html_mode the
        # chain does not matter at all, and under a Code ancestor nothing
        # after it does. The checks are spelled out instead of going
        # through a block, and the walk builds no array — every step
        # of the chain costs.
        #
        # A link label is where `]` is structural and must be escaped: a
        # link, a mail link, and the alt text of an image (ImageTag renders
        # it as a Text node under the Image). Tags that emit their own
        # bracketed markup (ImageTag, UploadTag, etc.) skip the text path
        # entirely, so their structural brackets are preserved.
        def render_text(node, context)
          # In html_mode even inside a code block we must HTML-escape, otherwise a
          # stray `<` in a code cell would break the surrounding <td>.
          return @html_escaper.escape(node.text) if context.html_mode?

          in_link_label = false

          # The chain always ends in a root context whose element is nil.
          while (parent = context.element)
            return node.text if parent.is_a?(AST::Code)

            in_link_label = true if parent.is_a?(AST::Url) || parent.is_a?(AST::Email) ||
              parent.is_a?(AST::Image)
            context = context.parent_context
          end

          @escaper.escape(node.text, in_link_label:)
        end
      end
    end
  end
end
