# frozen_string_literal: true

module Markbridge
  class Normalizer
    # The parent-aware tree-rewriting engine. One {Walker} is built per
    # {Normalizer#normalize} call (holding that call's {RuleSet} and
    # {Report}; no state is kept on the Normalizer). It changes the tree
    # in place via {AST::Element#replace_children}, touching only elements
    # whose children actually changed.
    #
    # The main rule is resolve-before-descend: a child's strategy is resolved
    # against its current ancestor stack first, and a moved subtree (hoist or
    # unwrap) is then walked against the ancestor stack it will have in its
    # new place. So a node that leaves a link does not see the link while its
    # own inside is normalized. That keeps a legally nested quote-in-quote or
    # image-in-quote intact, and it means a second normalize reports nothing.
    #
    # Hoisting: a node taken out of an inline container is moved up, tagged
    # with its boundary (the outermost matching ancestor, compared by
    # identity), and placed right after that boundary, at the boundary's
    # parent. A wrapper left empty by a hoist or drop is removed (see
    # {PRUNE_WHEN_EMPTY}), so no empty +**+ +**+ markers stay.
    #
    # For speed, the ancestor stack is one shared array that is pushed and
    # popped, and an element's children list is copied only when a child
    # first changes (copy-on-write). A subtree with no violations allocates
    # nothing and is left as it was, so the pass can run by default.
    class Walker
      EMPTY = [].freeze

      # Wrappers that mean nothing once they are empty, so an empty one is
      # removed instead of kept. +AST::Url+ is not here on purpose: an empty
      # link still renders as a bare URL, so a hoist that empties a link keeps
      # the link.
      PRUNE_WHEN_EMPTY = [
        AST::Bold,
        AST::Italic,
        AST::Underline,
        AST::Strikethrough,
        AST::Superscript,
        AST::Subscript,
        AST::Insertion,
        AST::Deletion,
        AST::Highlight,
        AST::Color,
        AST::Size,
        AST::Align,
        AST::Email,
      ].freeze

      # Stands in the child list where a block was hoisted out, until
      # {#coalesce} decides whether the two neighbors need a space.
      GAP = Object.new.freeze
      EDGE_SPACE_BEFORE = /[[:space:]]\z/
      EDGE_SPACE_AFTER = /\A[[:space:]]/
      # Stands in the child list where a block is split out: the children
      # behind it go into a copy of the element, and +node+ goes on
      # upward until it stands next to +boundary+.
      Split = Struct.new(:node, :boundary)
      BLANK = /\A[[:space:]]*\z/
      SPACE_AT_START = /\A[[:space:]]+/
      SPACE_AT_END = /[[:space:]]+\z/
      private_constant :GAP,
                       :EDGE_SPACE_BEFORE,
                       :EDGE_SPACE_AFTER,
                       :Split,
                       :BLANK,
                       :SPACE_AT_START,
                       :SPACE_AT_END

      # @param rule_set [RuleSet]
      # @param report [Report]
      def initialize(rule_set, report)
        @rules = rule_set
        @report = report
        # Per-run cache for RuleSet#resolve's ancestry analysis. A Walker
        # lives for one normalize call, so each distinct node class is
        # analyzed at most once per run while the RuleSet itself stays
        # free of per-call state.
        @walk_cache = {}
        # The copies of inline elements that {Carrier} has put into a
        # block. One that ends up empty is removed, whatever it is.
        @copies = Set.new.compare_by_identity
      end

      # Normalize +document+'s subtree in place.
      # @param document [AST::Document]
      def call(document)
        _element, bubble, _before, _after, tail = normalize_element(document, [])
        # Defensive: anything that never reached its boundary becomes a
        # trailing sibling rather than being lost. Well-formed rule tables
        # do not get here.
        tail.each do |part|
          # A rule that splits the document itself has nowhere to put the
          # parts: they stay its children, in their order.
          if part.instance_of?(Split)
            document << part.node
          else
            part.children.each { |c| document << c }
          end
        end
        bubble.each { |node, _boundary| document << node }
      end

      private

      # Copy-on-write check: a kept child that came back as the same object
      # (so normalizing it changed nothing) with no bubble, while nothing
      # earlier changed, needs no rebuilt +out+. This only saves work. If it
      # is wrong, the code still rebuilds the same child list, so its
      # mutations do not change the output.
      def unchanged?(out, normalized, child, child_bubble)
        out.nil? && normalized.equal?(child) && child_bubble.empty?
      end

      # Normalize a node's descendants. Elements recurse; leaves are
      # returned untouched. Returns +[node_or_nil, bubble, before, after,
      # tail]+ — +nil+ when the element was pruned, +bubble+ is the list of
      # +[node, boundary]+ pairs to hoist above this node. +before+ says
      # that a block left the start of the node, so what stands in front
      # of the node was on another line, and +after+ says the same for its
      # end and what follows it. +tail+ is what follows the node when it
      # was split: the blocks that were split out of it, each as a {Split}
      # until it has reached its boundary, and between them the copies of
      # the node with the children that stood behind each block.
      def normalize_node(node, stack)
        return node, EMPTY, false, false, EMPTY unless node.is_a?(AST::Element)

        normalize_element(node, stack)
      end

      # +stack+ is a shared, mutable ancestor stack (root first): +element+
      # is pushed for the duration of its children's processing and popped
      # after. +out+ (the rebuilt child list) and +bubble+ stay +nil+ until
      # a child actually changes, so the clean path allocates nothing.
      def normalize_element(element, stack)
        stack.push(element)
        children = element.children
        out = nil
        bubble = nil

        children.each_with_index do |child, index|
          strategy, boundary = @rules.decide(child, stack, @walk_cache)

          if strategy.nil? || strategy == :keep
            normalized, child_bubble, before, after, tail = normalize_node(child, stack)
            if !before && !after && tail.empty? && unchanged?(out, normalized, child, child_bubble)
              next
            end

            out ||= children[0, index]
            out << GAP if before
            bubble = append_kept(normalized, child_bubble, child, out, bubble)
            append_tail(tail, child, out)
            out << GAP if after
          else
            out ||= children[0, index]
            bubble = emit(child, strategy, boundary, stack, out, bubble)
          end
        end

        stack.pop
        raised = bubble || EMPTY
        unless out
          kept = prune?(element, nil, children) ? nil : element
          return kept, raised, false, false, EMPTY
        end

        # For a block the two say nothing new: the parent puts no
        # space next to a block anyway (see #touching?).
        before = out.first.equal?(GAP)
        after = out.last.equal?(GAP)
        return in_parts(element, out, raised, before, after) if out.any?(Split)

        out = coalesce(out)
        element.replace_children(out)
        kept = prune?(element, out, children) ? nil : element
        [kept, raised, before, after, EMPTY]
      end

      # The element whose children hold a {Split}: it keeps the children
      # in front of the first one, and a copy of it gets the children
      # behind each. A part that shows nothing is left out, the element
      # itself too, whatever it is: what it held is in the block now.
      def in_parts(element, out, raised, before, after)
        parts = [[]]
        out.each { |node| node.instance_of?(Split) ? parts.push(node, []) : parts.last << node }
        first, *rest = parts

        children = coalesce(first)
        trim(children, -1, SPACE_AT_END)
        element.replace_children(children)
        tail =
          rest.each_with_index.filter_map do |part, index|
            next part if part.instance_of?(Split)

            children_of_copy = coalesce(part)
            trim(children_of_copy, 0, SPACE_AT_START)
            trim(children_of_copy, -1, SPACE_AT_END) if index < rest.size - 1
            element.dup.replace_children(children_of_copy) unless blank?(children_of_copy)
          end
        kept = blank?(children) ? nil : element
        [kept, raised, before, after, tail]
      end

      # Takes the whitespace off a text that stands next to a block that
      # was split out: it is at the end or at the start of a line now.
      # A text that was nothing else is removed.
      def trim(nodes, index, pattern)
        node = nodes[index]
        return unless node.instance_of?(AST::Text)

        text = node.text.sub(pattern, "")
        text.empty? ? nodes.delete_at(index) : nodes[index] = AST::Text.new(text)
      end

      # Whether the nodes show nothing: there are none, or they are
      # whitespace.
      def blank?(nodes)
        nodes.all? { |node| node.instance_of?(AST::Text) && node.text.match?(BLANK) }
      end

      # Put what follows a child that was split behind it. A block that
      # has reached its boundary, which is the child, lands here. One
      # that has not goes on as a {Split} and splits this element too.
      def append_tail(tail, child, out)
        tail.each do |part|
          out << (part.instance_of?(Split) && part.boundary.equal?(child) ? part.node : part)
        end
      end

      # An element is removed when it ends up with no children and is one of
      # the wrappers in {PRUNE_WHEN_EMPTY}, or a copy that a split has made.
      def prune?(element, out, children)
        empty = out ? out.empty? : children.empty?
        empty && (PRUNE_WHEN_EMPTY.include?(element.class) || @copies.include?(element))
      end

      # Resolve one child (against +stack+) and place it into an existing
      # +out+ — the shared entry point used by {#emit}'s +:unwrap+ recursion,
      # where +out+ already exists.
      def resolve_into(child, stack, out, bubble)
        strategy, boundary = @rules.decide(child, stack, @walk_cache)

        if strategy.nil? || strategy == :keep
          child2, child_bubble, before, after, tail = normalize_node(child, stack)
          out << GAP if before
          bubble = append_kept(child2, child_bubble, child, out, bubble)
          append_tail(tail, child, out)
          out << GAP if after
          bubble
        else
          emit(child, strategy, boundary, stack, out, bubble)
        end
      end

      # Append a kept child that is already normalized, then place any of its
      # bubbles whose boundary is this child. ({#land} does nothing when
      # +child_bubble+ is empty, so there is no separate check for that.)
      def append_kept(normalized, child_bubble, child, out, bubble)
        out << normalized unless normalized.nil?
        land(child_bubble, child, out, bubble)
      end

      # Apply a non-keep strategy for +child+, appending to +out+ and
      # returning the (possibly newly allocated) +bubble+.
      def emit(child, strategy, boundary, stack, out, bubble)
        case strategy
        when :split
          split(child, boundary, stack, out, bubble)
        when :hoist_after
          out << GAP if block?(child)
          hoist(child, boundary, stack, bubble)
        when :unwrap
          unwrap(child, boundary, stack, out, bubble)
        when :textify
          @report.record(boundary.class, child.class, :textify)
          out << AST::Text.new(TextProjection.call(child))
          bubble
        when :drop
          @report.record(boundary.class, child.class, :drop)
          bubble
        when Array
          # A callable returned replacement nodes to splice in place.
          @report.record(boundary.class, child.class, :replace)
          strategy.each { |node| out << node }
          bubble
        else
          raise ArgumentError, "strategy resolved to #{strategy.inspect}"
        end
      end

      # Split the elements from the boundary down to here around the
      # block. The block takes copies of the inline formatting it was in
      # with it (see {Carrier}), then it is walked against the stack it
      # will have, like a hoisted one. It goes into +out+ as a {Split}:
      # this element and every one up to the boundary is cut there.
      def split(child, boundary, stack, out, bubble)
        @report.record(boundary.class, child.class, :split)
        above = ancestors_above(boundary, stack)
        carried = stack.drop(above.size).select { |ancestor| carried?(ancestor) }
        Carrier.call(child, carried, @copies)
        node, child_bubble, _before, _after, tail = normalize_node(child, above)
        out << Split.new(node, boundary) unless node.nil?
        # What the block itself was split into stays behind it.
        tail.each { |part| out << (part.instance_of?(Split) ? part : Split.new(part, boundary)) }
        return bubble if child_bubble.empty?

        bubble ||= []
        child_bubble.each { |entry| bubble << entry }
        bubble
      end

      def carried?(element)
        CARRIED.any? { |klass| element.is_a?(klass) }
      end

      def hoist(child, boundary, stack, bubble)
        @report.record(boundary.class, child.class, :hoist_after)
        # Walk the relocated subtree against its destination stack (the
        # ancestors strictly above the boundary) so its interior never sees
        # the boundary it is leaving.
        child2, child_bubble, _before, _after, tail =
          normalize_node(child, ancestors_above(boundary, stack))
        bubble ||= []
        bubble << [child2, boundary] unless child2.nil?
        tail.each { |part| bubble << [part.instance_of?(Split) ? part.node : part, boundary] }
        # What leaves the hoisted subtree itself comes after it, so it
        # lands behind it (see #land).
        child_bubble.each { |entry| bubble << entry }
        bubble
      end

      def unwrap(child, boundary, stack, out, bubble)
        # Unwrap means "promote the element's children"; a leaf has none. A
        # rule that targets one is a misconfiguration, so keep the node in
        # place rather than silently dropping it (and don't report a no-op).
        unless child.is_a?(AST::Element)
          out << child
          return bubble
        end

        @report.record(boundary.class, child.class, :unwrap)
        # Unwrap: run the child's children through the current +out+, resolved
        # against the current stack. Resolving them again in the same pass is
        # what fixes deeply nested links in one go.
        # A block that is unwrapped had its content on lines of its own.
        apart = block?(child)
        out << GAP if apart
        child.children.each { |grandchild| bubble = resolve_into(grandchild, stack, out, bubble) }
        out << GAP if apart
        bubble
      end

      # Land inbound bubbles whose boundary is +child+ (this level is the
      # boundary's parent), each after the previous to preserve order;
      # propagate the rest upward. A block that goes on upward stood at
      # the end of +child+ or behind it, so it leaves a gap here too:
      # what follows +child+ was on a line of its own.
      #
      # A node that lands here can be the boundary of a later one: a table
      # in a heading in bold leaves the heading, and the heading leaves
      # the bold. The table lands behind the heading then.
      def land(child_bubble, child, out, bubble)
        landed = nil
        child_bubble.each do |node, boundary|
          if boundary.equal?(child) || landed&.any? { |earlier| earlier.equal?(boundary) }
            out << node
            (landed ||= []) << node
          else
            out << GAP if block?(node)
            bubble ||= []
            bubble << [node, boundary]
          end
        end
        bubble
      end

      # Ancestors strictly above +boundary+ in +stack+ — the stack the
      # hoisted node inherits (its parent becomes the boundary's parent).
      def ancestors_above(boundary, stack)
        index = stack.index { |ancestor| ancestor.equal?(boundary) }
        stack.first(index)
      end

      # Finish a changed child list just before it is committed: adjacent
      # text is merged (textify can create neighbors that +#<<+ would have
      # merged), and the place a block was hoisted from gets a space when
      # its two neighbors would touch. With the block between them they
      # were on two lines, and an HTML parser has trimmed the whitespace
      # at such a line edge.
      #
      # A list, a table and a row get no space: their items, rows and
      # cells are blocks, and nothing touches a block (see #touching?).
      def coalesce(nodes)
        nodes
          .each_with_index
          .with_object([]) do |(node, index), acc|
            next if node.equal?(GAP)

            # For the first node this looks at the last one, which does no
            # harm: nothing is in front of the first node to touch.
            gap = nodes.fetch(index - 1).equal?(GAP)
            append(acc, AST::Text.new(" ")) if gap && touching?(acc.last, node)
            append(acc, node)
          end
      end

      def append(acc, node)
        last = acc.last
        # mergeable? is false when +last+ is nil (the first node), so no
        # separate nil-guard is needed.
        if mergeable?(last, node)
          last.merge(node)
        else
          acc << node
        end
      end

      # A block starts a line and ends one. Code or a spoiler that is
      # hoisted is a block, a code span or an inline spoiler stays where
      # it is.
      def block?(node)
        node.is_a?(AST::Code) || node.is_a?(AST::Spoiler) ||
          BLOCK_NODES.any? { |klass| node.is_a?(klass) }
      end

      def own_lines?(node)
        Normalizer.own_lines?(node)
      end

      # Whether +left+ and +right+ stand next to each other without
      # whitespace or a line break between them. Only text is looked into,
      # an inline element counts as something visible. A block is on lines
      # of its own, nothing touches it.
      def touching?(left, right)
        return false if left.nil? || left.instance_of?(AST::LineBreak) || own_lines?(left)
        return false if right.instance_of?(AST::LineBreak) || own_lines?(right)
        return false if left.instance_of?(AST::Text) && left.text.match?(EDGE_SPACE_BEFORE)

        !(right.instance_of?(AST::Text) && right.text.match?(EDGE_SPACE_AFTER))
      end

      def mergeable?(left, right)
        (left.instance_of?(AST::Text) && right.instance_of?(AST::Text)) ||
          (left.instance_of?(AST::MarkdownText) && right.instance_of?(AST::MarkdownText))
      end
    end
  end
end
