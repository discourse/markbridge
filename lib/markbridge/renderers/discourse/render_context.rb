# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Immutable context for rendering, implemented as a linked parent
      # chain: each context holds the nearest parent element plus a link
      # to the enclosing context. {#with_parent} runs once per rendered
      # element — the chain form makes it a single fixed-size allocation
      # instead of copying (and freezing) a parents array per element.
      # Provides query methods to ask about parent elements without the
      # renderer knowing about specific element types.
      class RenderContext
        # @return [Integer] number of parent elements in the chain
        attr_reader :depth

        # @return [AST::Element, nil] the nearest parent element (nil at root)
        attr_reader :element

        # @return [RenderContext, nil] the enclosing context (nil at root)
        attr_reader :parent_context

        # @return [AST::Element, nil] the element whose children are
        #   rendered at the root, when it has no tag of its own (the
        #   Document, as a rule). It is not on the parent chain, so the
        #   chain walks stay short; {RenderingInterface#previous_sibling}
        #   and {RenderingInterface#next_sibling} fall back to it.
        attr_reader :root

        # @param parents [Array<AST::Element>] parent elements in document
        #   order (outermost first); convenience form for building a
        #   context from scratch. Ignored when +element:+ is given.
        # @param html_mode [Boolean] see {#html_mode?}
        # @param parent [RenderContext, nil] enclosing context (chain form)
        # @param element [AST::Element, nil] nearest parent element (chain form)
        # @param root [AST::Element, nil] see {#root}
        def initialize(parents = [], html_mode: false, parent: nil, element: nil, root: nil)
          @html_mode = html_mode
          @root = root
          if element
            @parent_context = parent
            @element = element
            @depth = (parent ? parent.depth : 0) + 1
          elsif parents.empty?
            # Root context: @element and @parent_context stay unset and
            # read as nil.
            @depth = 0
          else
            @parent_context = self.class.new(parents[0, parents.size - 1], html_mode:, root:)
            @element = parents.last
            @depth = parents.size
          end
        end

        # Parent elements in document order (outermost first), materialized
        # from the chain into a frozen Array. Allocates on every call —
        # prefer {#find_parent} / {#has_parent?} / {#count_parents} on hot
        # paths.
        # @return [Array<AST::Element>]
        def parents
          result = []
          context = self
          while context && (parent = context.element)
            result << parent
            context = context.parent_context
          end
          result.reverse!
          result.freeze
        end

        # Create new context with element added to parent chain.
        # @param element [AST::Element]
        # @return [RenderContext]
        def with_parent(element)
          self.class.new(html_mode: @html_mode, parent: self, element:, root: @root)
        end

        # Create new context with html_mode toggled.
        # @param value [Boolean]
        # @return [RenderContext]
        def with_html_mode(value)
          self.class.new(html_mode: value, parent: @parent_context, element: @element, root: @root)
        end

        # Create new context with the root element set, see {#root}.
        # @param element [AST::Element]
        # @return [RenderContext]
        def with_root(element)
          self.class.new(
            html_mode: @html_mode,
            parent: @parent_context,
            element: @element,
            root: element,
          )
        end

        # @return [Boolean]
        def html_mode?
          @html_mode
        end

        # Find closest parent that is_a? klass (handles subclasses).
        # The chain walks are inlined in each query (instead of a shared
        # yielding helper) — these run several times per rendered text
        # node, and a plain while loop avoids the block invocation.
        # @param klass [Class]
        # @return [AST::Element, nil] nil when no parent matches (implicit
        #   from the exhausted while loop)
        def find_parent(klass)
          context = self
          while context && (parent = context.element)
            return parent if parent.is_a?(klass)
            context = context.parent_context
          end
        end

        # Count parents that are is_a? klass (handles subclasses).
        # @param klass [Class]
        # @return [Integer]
        def count_parents(klass)
          count = 0
          context = self
          while context && (parent = context.element)
            count += 1 if parent.is_a?(klass)
            context = context.parent_context
          end
          count
        end

        # Check if any parent is_a? klass (handles subclasses).
        # @param klass [Class]
        # @return [Boolean]
        def has_parent?(klass)
          context = self
          while context && (parent = context.element)
            return true if parent.is_a?(klass)
            context = context.parent_context
          end
          false
        end

        # Check if we're at the root (no parents).
        # @return [Boolean]
        def root?
          @depth.zero?
        end
      end
    end
  end
end
