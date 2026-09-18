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
        BACKSLASH = 92
        BANG = 33
        BRACKET_OPEN = 91
        private_constant :EMPHASIS_BOUNDARY,
                         :EMPHASIS_DELIMITER_BYTES,
                         :BACKSLASH,
                         :BANG,
                         :BRACKET_OPEN

        # Adjusts the end of +result+ where the next +part+ would change
        # how the characters on both sides are read. Works on bytes, so
        # the check per child allocates nothing. On an empty buffer
        # getbyte returns nil, which matches no byte of a non-empty part.
        def join(result, part)
          last_byte = result.getbyte(-1)
          first_byte = part.getbyte(0)

          if last_byte == first_byte && EMPHASIS_DELIMITER_BYTES.include?(last_byte)
            result << EMPHASIS_BOUNDARY
          elsif last_byte == BANG && first_byte == BRACKET_OPEN && result.getbyte(-2) != BACKSLASH
            # A `!` right in front of a link makes it an image. The escaper
            # leaves a lone `!` alone because it cannot see the next node.
            result.insert(-2, "\\")
          end
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
        def render_without_tag(node, context)
          case node
          when AST::Element # Document is an Element subclass
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
          # In html_mode even inside a code block we must HTML-escape, otherwise a
          # stray `<` in a code cell would break the surrounding <td>.
          if context.has_parent?(AST::Code)
            context.html_mode? ? @html_escaper.escape(node.text) : node.text
          elsif context.html_mode?
            @html_escaper.escape(node.text)
          else
            @escaper.escape(node.text, in_link_label: in_link_label?(context))
          end
        end

        # `]` is structural inside a Markdown link label, so any plain text
        # rendered under an Url/Email ancestor must escape it. The alt text
        # of an image is a link label too (ImageTag renders it as a Text
        # node under the Image). Tags that emit their own bracketed markup
        # (ImageTag, UploadTag, etc.) skip this path entirely, so their
        # structural brackets are preserved.
        def in_link_label?(context)
          context.has_parent?(AST::Url) || context.has_parent?(AST::Email) ||
            context.has_parent?(AST::Image)
        end
      end
    end
  end
end
