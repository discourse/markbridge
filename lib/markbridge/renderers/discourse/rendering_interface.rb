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

        def render_children(element, context: @context)
          @renderer.render_children(element, context:)
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

        # Check if element should be rendered in block context
        # @param node [AST::Node] container node or leaf like HorizontalRule
        # @return [Boolean]
        def block_context?(node)
          # Check if it's a block-level element type (but not code, which can be inline)
          return true if node.instance_of?(AST::List) || node.instance_of?(AST::HorizontalRule)
          return false unless node.is_a?(AST::Element)

          # Check if content has newlines
          node.children.any? { |c| c.instance_of?(AST::Text) && c.text.include?("\n") }
        end

        # Leading or trailing whitespace (Unicode-aware, matching the
        # flanking-preservation sub in #wrap_inline).
        EDGE_WHITESPACE = /\A[[:space:]]|[[:space:]]\z/m
        private_constant :EDGE_WHITESPACE

        # Helper: wrap inline content with markers
        # Handles edge cases like existing markers and whitespace
        def wrap_inline(content, open_marker, close_marker = nil)
          close_marker ||= open_marker
          return content unless content.match?(/[^[:space:]]/)

          # Handle conflicts with existing markers
          if content.include?(open_marker) || content.include?(close_marker)
            # Use HTML fallback for common cases
            case open_marker
            when "**"
              return "<strong>#{content}</strong>"
            when "*"
              return "<em>#{content}</em>"
            when "~~"
              return "<s>#{content}</s>"
            end
          end

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
