# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Renders AST to Discourse-flavored Markdown in-memory.
      class Renderer
        # @return [TagLibrary] the library the renderer renders with
        attr_reader :tag_library
        attr_reader :postprocessor

        def initialize(tag_library: nil, escaper: nil, html_escaper: nil, postprocessor: nil)
          @tag_library = tag_library || TagLibrary.shared_default
          @escaper = escaper || MarkdownEscaper.new
          @html_escaper = html_escaper || HtmlEscaper
          @postprocessor = postprocessor || Postprocessor::DEFAULT
          @serializer = Inline::Serializer.new(escaper: @escaper, html_escaper: @html_escaper)
          # @interface_cache and @resolved_tags are set up by a top-level
          # call and reset when it completes (see #reset_caches);
          # @resolved_default_tags stays for the life of the renderer.
        end

        # Renders a node to Markdown.
        #
        # @param node [AST::Node]
        # @param context [RenderContext] rendering context with parent chain
        # @return [String]
        # @raise [TypeError] when the tag bound to the node's class returns
        #   something other than a String or inline tokens (a nil from a
        #   custom tag would otherwise surface as an inscrutable
        #   concatenation error deep inside render_children)
        def render(node, context: RenderContext.new)
          root_call = enter

          serialize(render_output(node, context), context)
        ensure
          reset_caches if root_call
        end

        # Renders a node with the stock tag for its class, ignoring any
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
          root_call = enter

          tag = default_tag_library[node.class] || resolved_default_tag(node.class)
          output =
            tag ? tag.render(node, interface_for(context)) : render_without_tag(node, context)
          serialize(output, context)
        ensure
          reset_caches if root_call
        end

        # Writes inline tokens as Markdown, or as HTML in html_mode. A
        # String is returned as it is.
        #
        # @param output [String, Array<Array>] what a tag returned
        # @param context [RenderContext]
        # @return [String]
        def serialize(output, context)
          if output.instance_of?(String)
            output
          else
            @serializer.write(output, html_mode: context.html_mode?)
          end
        end

        # The output of a node as its tag returns it: finished Markdown,
        # or inline tokens (see Inline::Tokens) that the serializer writes
        # together with the output of the node's siblings.
        #
        # @param node [AST::Node]
        # @param context [RenderContext]
        # @return [String, Array<Array>]
        def render_output(node, context)
          # Exact-class hit first (a single Hash lookup, the common case),
          # then the memoized ancestry fallback so a subclass without its
          # own tag renders through its nearest ancestor's tag.
          tag = @tag_library[node.class] || resolved_tag(node.class)
          return render_without_tag(node, context) unless tag

          output = tag.render(node, interface_for(context))
          unless output.instance_of?(String) || output.instance_of?(Array)
            raise TypeError,
                  "#{tag.class} rendered #{node.class} to #{output.inspect} — tags must return " \
                    "a String or inline tokens (use interface.render_default(node) to fall " \
                    "back to the stock rendering)"
          end
          output
        end

        # The output of the children of a node as inline tokens, for a tag
        # that returns tokens itself. Finished Markdown from a child is a
        # token as it is.
        #
        # @param node [AST::Element]
        # @param context [RenderContext]
        # @return [Array<Array>]
        def render_tokens(node, context:)
          root_call = enter
          outer_parent = @child_parent
          outer_index = @child_index
          outer_list = @previous_list
          @child_parent = node
          @previous_list = continued_list(node, context, outer_list)
          tokens = []
          index = -1
          node.children.each do |child|
            @child_index = (index += 1)
            output = render_child(child, context)
            output.instance_of?(String) ? tokens << output : tokens.concat(output)
          end
          @child_parent = outer_parent
          @child_index = outer_index
          @previous_list = outer_list
          tokens
        ensure
          reset_caches if root_call
        end

        # Renders all children of a node and writes their output one after
        # the other with the Inline::Serializer, which knows what has to
        # happen where two outputs meet (see Inline::Joins).
        #
        # With a block, the block runs at every join point, right before
        # a non-empty child output is appended. It receives the buffer
        # built so far and the child about to be rendered into it, and
        # may change the buffer in place. A tag uses this to adjust the
        # text in front of a specific child without iterating the
        # children itself, which would lose the join rules.
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
        def render_children(node, context:, &block)
          root_call = enter
          outer_parent = @child_parent
          outer_index = @child_index
          outer_list = @previous_list
          @child_parent = node
          @previous_list = continued_list(node, context, outer_list)
          index = -1
          result =
            @serializer.write_groups(
              node.children,
              html_mode: context.html_mode?,
              before: block,
            ) do |child|
              @child_index = (index += 1)
              render_child(child, context)
            end
          @child_parent = outer_parent
          @child_index = outer_index
          @previous_list = outer_list
          result
        ensure
          reset_caches if root_call
        end

        # Renders one child of the element whose children are being
        # rendered, and remembers the last list among them for
        # #previous_list: a list, or a child whose output ends with one
        # (Tag#trailing_list). Text after it with something other than
        # whitespace in it keeps two lists apart; a child that renders to
        # nothing does not count.
        def render_child(child, context)
          output = render_output(child, context)
          list = child.is_a?(AST::Text) ? nil : trailing_list(child, context)
          if list
            @previous_list = list unless output.empty?
          elsif @previous_list && visible?(output)
            @previous_list = nil
          end
          output
        end

        def visible?(output)
          if output.instance_of?(String)
            Inline::Joins.visible?(output)
          else
            Inline::Tokens.visible?(output)
          end
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

        # The last list among the siblings in front of +element+, or the
        # sibling whose output ends with a list (Tag#trailing_list), when
        # nothing but whitespace or nodes that rendered to nothing came
        # after it. nil when there is none, or when +element+ is not the
        # child that #render_children is rendering right now.
        # @param element [AST::Node]
        # @return [AST::Node, nil]
        def previous_list(element)
          @previous_list if current_child?(element)
        end

        # The bullet characters and the ordered delimiters the lists are
        # written with, in the order they are tried.
        BULLET_MARKERS = ["- ", "* "].freeze
        ORDERED_MARKERS = ["1. ", "1) "].freeze

        # The marker for the items of +node+, a list or a node whose
        # output is a list (a poll without the plugin). Two lists of one
        # kind with the same marker and only whitespace between them cook
        # as one list, a different bullet character or ordered delimiter
        # starts a new list, so the list after #previous_list gets the
        # marker of its kind that list did not use. The marker is
        # remembered for +node+, see #list_marker.
        # @param node [AST::Node] the child #render_children is at;
        #   any other node gets the first marker of its kind
        # @param ordered [Boolean]
        # @return [String]
        def choose_list_marker(node, ordered:)
          root_call = enter
          markers = ordered ? ORDERED_MARKERS : BULLET_MARKERS
          # The marker of this kind that the list in front did not use;
          # the first one when none is in front.
          before = @list_markers[previous_list(node)]
          @list_markers[node] = (markers - [before]).first
        ensure
          reset_caches if root_call
        end

        # The marker #choose_list_marker picked for +node+ during this
        # render call, nil when it picked none. ListItemTag writes it in
        # front of the items, HorizontalRuleTag picks the characters of
        # its rule so they differ from it.
        # @param node [AST::Node]
        # @return [String, nil]
        def list_marker(node)
          @list_markers&.[](node)
        end

        # Whether +element+ is the child that #render_children is
        # rendering right now. The state above describes that child only.
        # @param element [AST::Node]
        # @return [Boolean]
        def current_child?(element)
          parent = child_parent
          !parent.nil? && parent.children.at(child_index).equal?(element)
        end

        # The list the output of +node+ starts with, as its tag says (see
        # Tag#leading_list). An element without a tag writes nothing but
        # its children, so its output starts with what the first child
        # with something in it starts with; +children: true+ asks that
        # for an element with a tag, for a tag whose output starts with
        # the children's.
        # @param node [AST::Node]
        # @param context [RenderContext]
        # @param children [Boolean]
        # @return [AST::List, nil]
        def leading_list(node, context, children: false)
          root_call = enter
          unless children
            tag = edge_tag(node)
            return tag.leading_list(node, interface_for(context)) if tag
          end
          first = node.is_a?(AST::Element) && node.children.find { |child| !whitespace?(child) }
          leading_list(first, context) if first
        ensure
          reset_caches if root_call
        end

        # The list the output of +node+ ends with, see #leading_list.
        # @param node [AST::Node]
        # @param context [RenderContext]
        # @param children [Boolean]
        # @return [AST::List, nil]
        def trailing_list(node, context, children: false)
          root_call = enter
          unless children
            tag = edge_tag(node)
            return tag.trailing_list(node, interface_for(context)) if tag
          end
          last =
            node.is_a?(AST::Element) &&
              node.children.reverse_each.find { |child| !whitespace?(child) }
          trailing_list(last, context) if last
        ensure
          reset_caches if root_call
        end

        private

        # Something other than whitespace.

        # Sets up the caches for a top-level call and says whether this is
        # one: a call from inside a tag finds them in place.
        def enter
          root_call = @interface_cache.nil?
          if root_call
            @interface_cache = {}
            @list_markers = {}.compare_by_identity
          end
          root_call
        end

        # The caches live for one top-level call: the tag library can
        # change between calls, and an interface is cached by the object
        # id of its context. The default library never changes, so its
        # resolved tags stay.
        def reset_caches
          @interface_cache = nil
          @resolved_tags = nil
          @list_markers = nil
        end

        def interface_for(context)
          @interface_cache[context.object_id] ||= RenderingInterface.new(self, context)
        end

        # The list in front of +node+ that the first list inside +node+
        # continues: the output of +node+ starts with that inner list
        # (Tag#leading_list), so the inner list gets the other marker.
        # nil when +node+ writes something of its own first, or when no
        # list came before it; the question is asked only then, it costs
        # a tag lookup on every element.
        # @param outer_list [AST::Node, nil] the last list in front of
        #   +node+, among the children of its parent
        # @return [AST::Node, nil]
        def continued_list(node, context, outer_list)
          outer_list if outer_list && leading_list(node, context)
        end

        # The tag of +node+ as #render_output finds it.
        def edge_tag(node)
          @tag_library[node.class] || resolved_tag(node.class)
        end

        # Text with nothing but whitespace writes nothing that keeps two
        # lists apart, see #render_child.
        def whitespace?(child)
          child.instance_of?(AST::Text) && child.text.strip.empty?
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
        # #render_default, kept for the life of the renderer.
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

        # In html_mode, pre-formatted Markdown is a Markdown island in a
        # `<div>`: the blank lines end the enclosing HTML block (e.g. a
        # <table>) so that CommonMark parses the content as Markdown, and
        # the `</div>` line opens the block again for the rest of the cell.
        def render_markdown_text(node, context)
          context.html_mode? ? HtmlBlock.enclosed_island(node.text) : node.text
        end

        # Text nodes are the most frequent nodes, so this walks the parent
        # chain once and takes the first answer it can: in html_mode the
        # chain does not matter at all, and under a Code ancestor nothing
        # after it does. The checks are spelled out instead of going
        # through a block, and the walk builds no array — every step
        # of the chain costs.
        #
        # A link label is where `]` is structural and must be escaped: a
        # link, a mail link, and the alt text of an image or an upload
        # (ImageTag and UploadTag render it as a Text node under their
        # element). The tags write their own brackets around it.
        def render_text(node, context)
          # In html_mode even inside a code block we must HTML-escape, otherwise a
          # stray `<` in a code cell would break the surrounding <td>. A
          # blank line would end the block, like the serializer's text
          # it is written as the entity.
          if context.html_mode?
            return HtmlBlock.without_blank_lines(@html_escaper.escape(node.text))
          end

          in_link_label = false

          # The chain always ends in a root context whose element is nil.
          while (parent = context.element)
            return node.text if parent.is_a?(AST::Code)

            in_link_label = true if parent.is_a?(AST::Url) || parent.is_a?(AST::Email) ||
              parent.is_a?(AST::Image) || parent.is_a?(AST::Upload)
            context = context.parent_context
          end

          @escaper.escape(node.text, in_link_label:)
        end
      end
    end
  end
end
