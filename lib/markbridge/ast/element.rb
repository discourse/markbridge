# frozen_string_literal: true

module Markbridge
  module AST
    # Base class for all AST elements that can contain children.
    # Elements form the structural nodes of the AST tree, while Text nodes are leaves.
    #
    # @example Creating an element with children
    #   element = AST::Bold.new
    #   element << AST::Text.new("hello")
    #   element << AST::Text.new(" world")
    #   element.children.size # => 1 (consecutive text nodes are merged)
    class Element < Node
      # @return [Array<Node>] the child nodes of this element
      attr_reader :children

      def initialize
        @children = []
      end

      # Add a child node to this element.
      # Consecutive Text nodes are automatically merged for optimization.
      #
      # @param child [Node] the node to add as a child
      # @return [Element] self for method chaining
      # @raise [TypeError] if child is not a Node instance
      #
      # @example Adding children
      #   element << AST::Text.new("hello")
      #   element << AST::Bold.new
      def <<(child)
        unless child.is_a?(Node)
          actual = child.nil? ? "nil" : child.class
          raise TypeError, "<< on #{self.class} expected a #{Node}, got #{actual}"
        end

        if child.instance_of?(Text) && children.last.instance_of?(Text)
          @children.last.merge(child)
        else
          @children << child
        end

        self
      end

      # Depth-first pre-order traversal yielding every descendant node.
      # Returns an +Enumerator+ when called without a block so it
      # composes through +Enumerable+:
      #
      #   document.each_descendant.select { |n| n.is_a?(AST::Url) }
      #
      # Iteration semantics: each Element snapshots its own +children+
      # array at the moment iteration enters it, so replacing a child
      # via {#replace_child} mid-walk is safe — descent uses the
      # pre-replacement reference. Adding or removing siblings on an
      # Element you are currently descending into is *not* guaranteed
      # to be visible to the current walk.
      #
      # @yieldparam node [Node] each descendant in document order
      # @return [Enumerator, Element] +Enumerator+ without a block, +self+ otherwise
      def each_descendant(&block)
        return enum_for(:each_descendant) unless block_given?

        @children.dup.each do |child|
          yield child
          child.each_descendant(&block) if child.is_a?(Element)
        end
        self
      end

      # Array of descendant nodes, optionally filtered by class.
      #
      #   document.descendants                    # every descendant
      #   document.descendants(AST::Url)          # every Url descendant
      #
      # @param klass [Class, nil] when given, only descendants that
      #   +is_a?(klass)+ are returned
      # @return [Array<Node>]
      def descendants(klass = nil)
        result = each_descendant.to_a
        return result if klass.nil?

        result.select { |node| node.is_a?(klass) }
      end

      # Replace a direct child of this Element with a different Node.
      # Preserves the child's index — useful for AST-mutation passes
      # that need to swap one Element type for another in place
      # (e.g. wrapping trailing paragraphs in a +Details+ block).
      #
      # @param old_child [Node] the child to remove (matched by +equal?+ via {Array#index})
      # @param new_child [Node] the replacement
      # @return [Element] +self+
      # @raise [ArgumentError] when +old_child+ is not currently a child of this Element
      # @raise [TypeError] when +new_child+ is not a {Node}
      def replace_child(old_child, new_child)
        index = @children.index(old_child)
        raise ArgumentError, "child not found in #{self.class}" if index.nil?

        unless new_child.is_a?(Node)
          actual = new_child.nil? ? "nil" : new_child.class
          raise TypeError, "replace_child on #{self.class} expected a #{Node}, got #{actual}"
        end

        @children[index] = new_child
        self
      end

      # Replace this element's entire child list in one shot.
      #
      # A plain validated setter for tree-rewriting passes (e.g. the
      # {Markbridge::Normalizer}) that rebuild an element's children out
      # of band and need to commit the result without re-running the
      # per-append logic of {#<<}. Every entry must be a {Node}.
      #
      # NOTE: unlike {#<<}, this does *not* merge adjacent {Text} nodes —
      # the auto-merge invariant is a property of {#<<} only. Callers that
      # build the array themselves own that coalescing (the Normalizer's
      # walker merges adjacent text as it assembles the list, so it never
      # hands a state {#<<} would not have produced).
      #
      # @param new_children [Array<Node>] the replacement children
      # @return [Element] +self+
      # @raise [TypeError] when any entry is not a {Node}
      def replace_children(new_children)
        new_children.each do |child|
          next if child.is_a?(Node)

          actual = child.nil? ? "nil" : child.class
          raise TypeError, "replace_children on #{self.class} expected #{Node}s, got #{actual}"
        end

        @children = new_children
        self
      end
    end
  end
end
