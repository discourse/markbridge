# frozen_string_literal: true

module Markbridge
  module Renderers
    module Discourse
      # Interface that tags use for rendering operations
      # Decouples tags from renderer implementation details
      class RenderingInterface
        attr_reader :context

        def initialize(renderer, context)
          @renderer = renderer
          @context = context
        end

        # Core rendering operations
        def render_node(node, context: @context)
          @renderer.render(node, context:)
        end

        # Render a node with the stock tag for its class, bypassing any
        # override in the renderer's tag library. Lets a custom tag handle
        # only the nodes it cares about and delegate the rest — see
        # Renderer#render_default.
        def render_default(node, context: @context)
          @renderer.render_default(node, context:)
        end

        # An optional block runs at every join point, before a non-empty
        # child output is appended — see Renderer#render_children.
        def render_children(element, context: @context, &block)
          @renderer.render_children(element, context:, &block)
        end

        # The output of the children as inline tokens, for a tag that
        # returns tokens itself — see Renderer#render_tokens.
        def render_tokens(element, context: @context)
          @renderer.render_tokens(element, context:)
        end

        # Context operations
        def with_parent(element)
          @context.with_parent(element)
        end

        def with_html_mode(value)
          @context.with_html_mode(value)
        end

        def html_mode?
          @context.html_mode?
        end

        def find_parent(klass)
          @context.find_parent(klass)
        end

        def count_parents(klass)
          @context.count_parents(klass)
        end

        def has_parent?(klass)
          @context.has_parent?(klass)
        end

        def root?
          @context.root?
        end

        # The node in front of +element+ among the children of its parent.
        # nil when +element+ is the first child, or when the parent is not
        # known.
        # @param element [AST::Node]
        # @return [AST::Node, nil]
        def previous_sibling(element)
          sibling(element, offset: -1)
        end

        # The node after +element+ among the children of its parent.
        # @param element [AST::Node]
        # @return [AST::Node, nil]
        def next_sibling(element)
          sibling(element, offset: 1)
        end

        # The node +offset+ positions away from +element+ among the
        # children of its parent (negative: in front of it). nil when
        # there is no node at that position, or when the parent is not
        # known.
        #
        # The renderer knows the element whose children it renders and
        # the position of the child it renders right now, so the usual
        # call costs no search, and an element without a tag (which is
        # not on the parent chain) is found as the parent too. For any
        # other element the parent is the element on top of the parent
        # chain, or the root element when the chain is empty, and its
        # children are searched.
        # @param element [AST::Node]
        # @param offset [Integer]
        # @return [AST::Node, nil]
        def sibling(element, offset:)
          if @renderer.current_child?(element)
            parent = @renderer.child_parent
            index = @renderer.child_index
          else
            parent = @context.element || @context.root
            return nil if parent.nil?

            index = parent.children.index { |child| child.equal?(element) }
            return nil if index.nil?
          end

          target = index + offset
          parent.children.at(target) unless target.negative?
        end

        # The last list among the siblings in front of +element+ with
        # nothing but whitespace, or nodes that rendered to nothing,
        # after it. See Renderer#previous_list.
        # @param element [AST::Node]
        # @return [AST::List, nil]
        def previous_list(element)
          @renderer.previous_list(element)
        end

        # Check if element should be rendered in block context
        # @param node [AST::Node] container node or leaf like HorizontalRule
        # @return [Boolean]
        def block_context?(node)
          # Check if it's a block-level element type (but not code, which can be inline)
          return true if node.instance_of?(AST::List) || node.instance_of?(AST::HorizontalRule)
          # A Code node whose source construct is a block by definition keeps
          # its block form even with single-line content (is_a?, so Code
          # subclasses inherit the behavior).
          return true if node.is_a?(AST::Code) && node.block
          return false unless node.is_a?(AST::Element)

          # Check if content has newlines
          node.children.any? { |c| c.instance_of?(AST::Text) && c.text.include?("\n") }
        end

        # Leading or trailing whitespace (Unicode-aware, matching the
        # flanking-preservation sub in #wrap_inline).
        EDGE_WHITESPACE = /\A[[:space:]]|[[:space:]]\z/m
        private_constant :EDGE_WHITESPACE

        # Wraps inline content in markers, with whitespace at the edges
        # outside the markers. Content with nothing visible in it is
        # returned as it is.
        def wrap_inline(content, open_marker, close_marker = nil)
          close_marker ||= open_marker
          return content unless content.match?(/[^[:space:]]/)

          apply_markers(content, open_marker, close_marker)
        end

        private

        # Wrap content in markers, keeping leading/trailing whitespace
        # outside the markers (Unicode-aware, since CommonMark's flanking
        # rules treat e.g. nbsp as whitespace).
        def apply_markers(content, open_marker, close_marker)
          # Fast path: no edge whitespace to preserve (the common case), so
          # plain interpolation replaces the capture-group sub below and its
          # MatchData + capture allocations.
          return "#{open_marker}#{content}#{close_marker}" unless content.match?(EDGE_WHITESPACE)

          content.sub(/\A([[:space:]]*)(.+?)([[:space:]]*)\z/m) do
            match = Regexp.last_match
            "#{match[1]}#{open_marker}#{match[2]}#{close_marker}#{match[3]}"
          end
        end
      end
    end
  end
end
