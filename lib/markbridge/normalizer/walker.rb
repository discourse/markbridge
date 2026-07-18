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
        AST::Color,
        AST::Size,
        AST::Align,
        AST::Email,
      ].freeze

      # @param rule_set [RuleSet]
      # @param report [Report]
      def initialize(rule_set, report)
        @rules = rule_set
        @report = report
      end

      # Normalize +document+'s subtree in place.
      # @param document [AST::Document]
      def call(document)
        _element, bubble = normalize_element(document, [])
        # Defensive: anything that never reached its boundary becomes a
        # trailing sibling rather than being lost. Well-formed rule tables
        # do not get here.
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
      # returned untouched. Returns +[node_or_nil, bubble]+ — +nil+ when the
      # element was pruned, and +bubble+ is the list of +[node, boundary]+
      # pairs to hoist above this node.
      def normalize_node(node, stack)
        return node, EMPTY unless node.is_a?(AST::Element)

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
          strategy, boundary = @rules.resolve(child, stack)
          strategy = strategy.call(boundary, child) if strategy.respond_to?(:call)

          if strategy.nil? || strategy == :keep
            normalized, child_bubble = normalize_node(child, stack)
            next if unchanged?(out, normalized, child, child_bubble)

            out ||= children[0, index]
            bubble = append_kept(normalized, child_bubble, child, out, bubble)
          else
            out ||= children[0, index]
            bubble = emit(child, strategy, boundary, stack, out, bubble)
          end
        end

        stack.pop
        element.replace_children(coalesce(out)) if out

        raised = bubble || EMPTY
        return nil, raised if prune?(element, out, children)

        [element, raised]
      end

      # An element is removed when it ends up with no children and is one of
      # the wrappers in {PRUNE_WHEN_EMPTY}.
      def prune?(element, out, children)
        empty = out ? out.empty? : children.empty?
        empty && PRUNE_WHEN_EMPTY.include?(element.class)
      end

      # Resolve one child (against +stack+) and place it into an existing
      # +out+ — the shared entry point used by {#emit}'s +:unwrap+ recursion,
      # where +out+ already exists.
      def resolve_into(child, stack, out, bubble)
        strategy, boundary = @rules.resolve(child, stack)
        strategy = strategy.call(boundary, child) if strategy.respond_to?(:call)

        if strategy.nil? || strategy == :keep
          child2, child_bubble = normalize_node(child, stack)
          append_kept(child2, child_bubble, child, out, bubble)
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
        when :hoist_after
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

      def hoist(child, boundary, stack, bubble)
        @report.record(boundary.class, child.class, :hoist_after)
        # Walk the relocated subtree against its destination stack (the
        # ancestors strictly above the boundary) so its interior never sees
        # the boundary it is leaving.
        child2, child_bubble = normalize_node(child, ancestors_above(boundary, stack))
        bubble ||= []
        bubble << [child2, boundary] unless child2.nil?
        # For the built-in tables a hoisted subtree yields no escaping
        # bubbles; carry any (from a custom rule) up as a best effort.
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
        child.children.each { |grandchild| bubble = resolve_into(grandchild, stack, out, bubble) }
        bubble
      end

      # Land inbound bubbles whose boundary is +child+ (this level is the
      # boundary's parent), each after the previous to preserve order;
      # propagate the rest upward.
      def land(child_bubble, child, out, bubble)
        child_bubble.each do |node, boundary|
          if boundary.equal?(child)
            out << node
          else
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

      # Coalesce adjacent text (textify can create neighbours that +#<<+
      # would have merged) just before committing a changed child list.
      def coalesce(nodes)
        nodes.each_with_object([]) do |node, acc|
          last = acc.last
          # mergeable? is false when +last+ is nil (the first node), so no
          # separate nil-guard is needed.
          if mergeable?(last, node)
            last.merge(node)
          else
            acc << node
          end
        end
      end

      def mergeable?(left, right)
        (left.instance_of?(AST::Text) && right.instance_of?(AST::Text)) ||
          (left.instance_of?(AST::MarkdownText) && right.instance_of?(AST::MarkdownText))
      end
    end
  end
end
